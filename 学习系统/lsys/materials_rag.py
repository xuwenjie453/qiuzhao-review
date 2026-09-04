# -*- coding: utf-8 -*-
"""资料库 Hybrid RAG: Document → Section → Concept Chunk; FTS5 关键词 + Embedding 语义; Small-to-Big。
原始资料是 Source of Truth; 不改原文件; 增量索引(hash diff)。
"""
import os, re, io, json, math, sqlite3, hashlib, struct, datetime, subprocess, tempfile

from . import db, schema

ROOT = db.ROOT
MATERIALS_DIR = os.path.join(ROOT, '资料库')
INDEX_DIR = os.path.join(MATERIALS_DIR, 'index')
EMBED_MODEL = 'char-bigram-hash-v1'   # 确定性本地向量; 接口不变, 可替换为真实 embedding 模型
EMBED_DIM = 256
MAX_CHUNKS_PER_DOC = 3000
TEXT_EXTS = {'.md', '.txt', '.markdown'}
PDF_EXTS = {'.pdf'}
SKIP_DIRS = {'index', '__MACOSX'}


# ---------- embedding ----------
def embed(text: str) -> bytes:
    """字符 bigram 哈希到 256 维, L2 归一化。语义≈词面; 模型可升级而不改表结构。"""
    vec = [0.0] * EMBED_DIM
    s = re.sub(r'\s+', '', text.lower())
    for i in range(len(s) - 1):
        h = int(hashlib.md5(s[i:i + 2].encode()).hexdigest()[:8], 16)
        vec[h % EMBED_DIM] += 1.0
    n = math.sqrt(sum(v * v for v in vec)) or 1.0
    return struct.pack(f'{EMBED_DIM}f', *[v / n for v in vec])


def cosine(a_blob: bytes, b_blob: bytes) -> float:
    a = struct.unpack(f'{EMBED_DIM}f', a_blob)
    b = struct.unpack(f'{EMBED_DIM}f', b_blob)
    return sum(x * y for x, y in zip(a, b))


# ---------- 文本抽取 ----------
def extract_text(path: str) -> str | None:
    ext = os.path.splitext(path)[1].lower()
    try:
        if ext in TEXT_EXTS:
            with open(path, encoding='utf-8', errors='ignore') as f:
                return f.read()
        if ext in PDF_EXTS:
            with tempfile.NamedTemporaryFile(suffix='.txt', delete=False) as tf:
                out = tf.name
            r = subprocess.run(['pdftotext', '-layout', path, out], capture_output=True, timeout=300)
            if r.returncode != 0:
                os.unlink(out); return None
            with open(out, encoding='utf-8', errors='ignore') as f:
                text = f.read()
            os.unlink(out)
            return text
    except Exception:
        return None
    return None


def chunk_document(title: str, text: str) -> list:
    """Document → Section → Concept。返回 [{level, heading_path, content, start, parent_idx}]
    parent_idx 指向列表内父块下标(-1=无); 由调用方生成 chunk_id 并落实 parent_chunk_id。"""
    chunks = []
    lines = text.split('\n')
    offset = 0
    sections = []   # (heading_path, start_line, end_line)
    cur_head, cur_start = '', 0
    for i, ln in enumerate(lines):
        m = re.match(r'^(#{1,6})\s+(.*)', ln) or re.match(r'^(第[一二三四五六七八九十0-9]+[章节篇]).{0,40}$', ln.strip())
        if m:
            if i > cur_start:
                sections.append((cur_head, cur_start, i))
            cur_head = (m.group(2) if m.lastindex >= 2 else m.group(1))[:80]
            cur_start = i
    sections.append((cur_head, cur_start, len(lines)))
    for head, a, b in sections:
        body = '\n'.join(lines[a:b]).strip()
        if not body:
            continue
        start_off = sum(len(l) + 1 for l in lines[:a])
        # Section (L1)
        if 200 <= len(body) <= 1600:
            chunks.append({'level': 1, 'heading_path': head, 'content': body, 'start': start_off})
        else:
            if len(body) > 200:
                chunks.append({'level': 1, 'heading_path': head, 'content': body[:1600], 'start': start_off})
            # Concept (L2): 按空行/句号分段
            buf, blen = [], 0
            seg_start = start_off
            for para in re.split(r'\n\s*\n|(?<=[。！？!?])', body):
                para = para.strip()
                if not para:
                    continue
                buf.append(para); blen += len(para)
                if blen >= 600:
                    c = '\n'.join(buf)
                    chunks.append({'level': 2, 'heading_path': head, 'content': c[:1200], 'start': seg_start, 'parent_idx': len(chunks) - 1})
                    buf, blen = [], 0
                    seg_start += len(c)
            if buf and blen >= 120:
                chunks.append({'level': 2, 'heading_path': head, 'content': '\n'.join(buf)[:1200], 'start': seg_start, 'parent_idx': len(chunks) - 1})
        if len(chunks) >= MAX_CHUNKS_PER_DOC:
            break
    if not chunks and text.strip():
        chunks.append({'level': 0, 'heading_path': '', 'content': text.strip()[:1600], 'start': 0, 'parent_idx': -1})
    return chunks


# ---------- 增量索引 ----------
def scan_files() -> list:
    out = []
    for root, dirs, files in os.walk(MATERIALS_DIR):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in files:
            ext = os.path.splitext(f)[1].lower()
            if ext in TEXT_EXTS | PDF_EXTS:
                out.append(os.path.join(root, f))
    return sorted(out)


def index_materials(limit_files: int | None = None, verbose: bool = False) -> dict:
    os.makedirs(INDEX_DIR, exist_ok=True)
    conn = db.connect(db.DB_MATERIALS, init=True)
    stats = {'scanned': 0, 'indexed': 0, 'skipped_unchanged': 0, 'failed': 0, 'chunks': 0}
    files = scan_files()
    if limit_files:
        files = files[:limit_files]
    for path in files:
        stats['scanned'] += 1
        rel = os.path.relpath(path, ROOT)
        try:
            with open(path, 'rb') as f:
                h = hashlib.sha256(f.read()).hexdigest()
            row = conn.execute("SELECT content_hash FROM documents WHERE path=?", (rel,)).fetchone()
            if row and row['content_hash'] == h:
                stats['skipped_unchanged'] += 1
                continue
            text = extract_text(path)
            if not text or len(text.strip()) < 50:
                stats['failed'] += 1
                continue
            if row:  # 内容变化: 删旧 chunks
                conn.execute("DELETE FROM chunks WHERE document_id IN (SELECT document_id FROM documents WHERE path=?)", (rel,))
                conn.execute("DELETE FROM documents WHERE path=?", (rel,))
            did = db.uid('doc')
            title = os.path.basename(path)
            chunks = chunk_document(title, text)
            now = db.now()
            conn.execute("""INSERT INTO documents(document_id,path,title,content_hash,file_type,chunk_count,indexed_at,updated_at)
                            VALUES (?,?,?,?,?,?,?,?)""",
                         (did, rel, title, h, os.path.splitext(path)[1][1:], len(chunks), now, now))
            all_chunks = [{'level': 0, 'heading_path': '', 'content': f'{title}\n' + '\n'.join(
                re.findall(r'^(#{1,3} .*)', text, re.M)[:30]), 'start': 0, 'parent_idx': -1}] + chunks
            chunk_ids = []
            for c in all_chunks:
                cid = db.uid('chk')
                chunk_ids.append(cid)
                parent_cid = chunk_ids[c['parent_idx']] if c.get('parent_idx', -1) >= 0 else None
                conn.execute("""INSERT INTO chunks(chunk_id,document_id,parent_chunk_id,level,heading_path,content,start_offset,end_offset,content_hash)
                                VALUES (?,?,?,?,?,?,?,?,?)""",
                             (cid, did, parent_cid, c['level'], c['heading_path'], c['content'],
                              c['start'], c['start'] + len(c['content']), hashlib.sha256(c['content'].encode()).hexdigest()[:16]))
                conn.execute("INSERT INTO chunks_fts(content, heading_path, chunk_id) VALUES (?,?,?)",
                             (c['content'], c['heading_path'], cid))
                vec = embed(c['content'])
                conn.execute("INSERT INTO embedding_vec(chunk_id,model,dim,vec) VALUES (?,?,?,?)",
                             (cid, EMBED_MODEL, EMBED_DIM, vec))
                conn.execute("INSERT INTO chunk_embeddings(chunk_id,embedding_model,vector_ref,generated_at) VALUES (?,?,?,?)",
                             (cid, EMBED_MODEL, f'db:embedding_vec:{cid}', now))
                stats['chunks'] += 1
            conn.execute("UPDATE documents SET chunk_count=? WHERE document_id=?", (len(all_chunks), did))
            stats['indexed'] += 1
            if verbose:
                print(f"  indexed {rel}: {len(chunks)} chunks")
        except Exception as e:
            stats['failed'] += 1
            if verbose:
                print(f"  FAIL {rel}: {e}")
    conn.commit()
    total = conn.execute("SELECT count(*) AS n FROM chunks").fetchone()['n']
    docs = conn.execute("SELECT count(*) AS n FROM documents").fetchone()['n']
    conn.close()
    stats['total_chunks'] = total
    stats['total_documents'] = docs
    return stats


# ---------- Hybrid Retrieval ----------
def retrieve(query: str, top_k: int = 8, level: int | None = None) -> list:
    """并行 FTS5 关键词 + embedding 语义, 分数归一融合。"""
    conn = db.connect(db.DB_MATERIALS, init=True)
    try:
        # FTS5
        kw = {}
        try:
            terms = [x for x in re.findall(r'[\w\u4e00-\u9fff]{2,}', query)][:8]
            hit = {}          # chunk_id -> {term: rank_score}
            tweight = {}      # term -> 稀缺度权重(匹配越少越关键)
            for term in terms:
                rows = conn.execute("""SELECT chunk_id, bm25(chunks_fts) AS rank FROM chunks_fts
                                       WHERE chunks_fts MATCH ? ORDER BY rank LIMIT 30""", (term,)).fetchall()
                mx = min((r['rank'] for r in rows), default=None)
                if mx is None or mx >= 0:
                    continue
                cnt = conn.execute("SELECT count(*) AS n FROM chunks_fts WHERE chunks_fts MATCH ?", (term,)).fetchone()['n']
                tweight[term] = 1.0 / math.log(2.0 + cnt)
                for r in rows:
                    hit.setdefault(r['chunk_id'], {})[term] = r['rank'] / mx
            total_w = sum(tweight.values()) or 1.0
            for cid, terms_hit in hit.items():
                wsum = sum(tweight[tm] for tm in terms_hit)
                best = max(terms_hit.values())
                kw[cid] = best * (wsum / total_w) ** 1.2
        except sqlite3.OperationalError:
            pass
        # Embedding
        qv = embed(query)
        sem = []
        sql = "SELECT v.chunk_id, v.vec FROM embedding_vec v JOIN chunks c ON c.chunk_id=v.chunk_id"
        if level is not None:
            sql += " WHERE c.level=?"
            for cid, blob in conn.execute(sql, (level,)):
                sem.append((cid, cosine(qv, blob)))
        else:
            for cid, blob in conn.execute(sql):
                sem.append((cid, cosine(qv, blob)))
        sem.sort(key=lambda x: -x[1])
        top_sem = sem[:40]
        smax = max((s for _, s in top_sem), default=1) or 1
        scores = {}
        for cid, s in top_sem:
            scores[cid] = scores.get(cid, 0) + 0.5 * (s / smax)
        for cid, s in kw.items():
            scores[cid] = scores.get(cid, 0) + 0.5 * s
        ranked = sorted(scores.items(), key=lambda x: -x[1])[:top_k]
        out = []
        for cid, score in ranked:
            r = conn.execute("""SELECT c.chunk_id, c.document_id, c.level, c.heading_path, c.content, d.path, d.title
                                FROM chunks c JOIN documents d ON d.document_id=c.document_id WHERE c.chunk_id=?""", (cid,)).fetchone()
            if r:
                out.append({'chunk_id': r['chunk_id'], 'level': r['level'], 'heading_path': r['heading_path'],
                            'content': r['content'][:800], 'source': r['path'], 'title': r['title'],
                            'score': round(score, 3)})
        return out
    finally:
        conn.close()


def small_to_big(chunk_id: str, extra_parent: bool = True) -> list:
    """Atomic 命中后按需拉父块补上下文。"""
    conn = db.connect(db.DB_MATERIALS, init=True)
    try:
        out = []
        seen = set()
        cur = chunk_id
        while cur and cur not in seen:
            seen.add(cur)
            r = conn.execute("""SELECT c.chunk_id, c.parent_chunk_id, c.level, c.heading_path, c.content, d.path
                                FROM chunks c JOIN documents d ON d.document_id=c.document_id WHERE c.chunk_id=?""", (cur,)).fetchone()
            if not r:
                break
            out.append({'chunk_id': r['chunk_id'], 'level': r['level'], 'heading_path': r['heading_path'],
                        'content': r['content'][:1200], 'source': r['path']})
            cur = r['parent_chunk_id'] if extra_parent else None
        return out
    finally:
        conn.close()
