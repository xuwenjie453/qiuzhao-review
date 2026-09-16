# -*- coding: utf-8 -*-
"""用户自拟问题图的独立周期调度。

图内容以 DualEnd QuestionGraph 为事实来源；本模块只在 scheduler.sqlite3
保存周期、到期投影和不可覆盖的复习事件。
"""
from __future__ import annotations

import datetime
import json
import os
import sqlite3

from . import db


SCHEDULING_VERSION = "user-graph-sequence-v1"
CADENCES = {
    "HIGH": [1, 2, 4, 7, 14, 30],
    "MEDIUM": [3, 7, 14, 30, 60],
    "LOW": [7, 21, 45, 90],
}
FREQUENCY_ALIASES = {
    "high": "HIGH", "高": "HIGH", "高频": "HIGH",
    "medium": "MEDIUM", "mid": "MEDIUM", "中": "MEDIUM", "中频": "MEDIUM",
    "low": "LOW", "低": "LOW", "低频": "LOW",
}


def _now(value: datetime.datetime | None = None) -> datetime.datetime:
    return value or datetime.datetime.now().astimezone()


def _frequency(value: str | None) -> str:
    raw = str(value or "medium").strip()
    normalized = FREQUENCY_ALIASES.get(raw.lower()) or FREQUENCY_ALIASES.get(raw) or raw.upper()
    if normalized not in CADENCES:
        raise ValueError("frequency 必须是 high/medium/low（高频/中频/低频）")
    return normalized


def _graph_db_path(path: str | None = None) -> str:
    return path or os.path.join(db.ROOT, "系统数据", "dual-end", "state", "dual-end.db")


def _assert_user_graph(custom_id: str, graph_db_path: str | None = None) -> dict:
    path = _graph_db_path(graph_db_path)
    if not os.path.exists(path):
        raise ValueError("QuestionGraph 状态库不存在")
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    try:
        row = conn.execute("""SELECT g.graph_id,g.source_id AS custom_id,n.title,n.body_markdown
            FROM graphs g JOIN nodes n ON n.node_id=g.center_node_id
            WHERE g.question_source='USER_AUTHORED' AND g.source_id=?""", (custom_id,)).fetchone()
        if not row:
            raise ValueError(f"找不到自拟问题图: {custom_id}")
        return dict(row)
    finally:
        conn.close()


def _event(conn: sqlite3.Connection, custom_id: str, event_type: str, frequency: str,
           sequence_index: int, due_at: str | None, payload: dict | None = None,
           occurred_at: str | None = None) -> None:
    conn.execute("""INSERT INTO user_graph_review_events
        (event_id,custom_id,occurred_at,event_type,frequency,sequence_index,due_at,payload_json)
        VALUES (?,?,?,?,?,?,?,?)""",
        (db.uid("ugrev"), custom_id, occurred_at or db.now(), event_type, frequency,
         sequence_index, due_at, json.dumps(payload, ensure_ascii=False) if payload else None))


def register(custom_id: str, frequency: str = "medium", now_dt: datetime.datetime | None = None,
             scheduler_path: str | None = None, graph_db_path: str | None = None) -> dict:
    graph = _assert_user_graph(custom_id, graph_db_path)
    freq = _frequency(frequency)
    cadence = CADENCES[freq]
    now_dt = _now(now_dt)
    path = scheduler_path or db.DB_SCHEDULER
    conn = db.connect(path, init=True)
    try:
        existing = conn.execute("SELECT * FROM user_graph_review_schedule WHERE custom_id=?", (custom_id,)).fetchone()
        if existing:
            if existing["frequency"] != freq:
                conn.close()
                return set_frequency(custom_id, freq, now_dt=now_dt, scheduler_path=path,
                                     graph_db_path=graph_db_path)
            return {**dict(existing), "title": graph["title"], "created": False,
                    "scheduling_version": SCHEDULING_VERSION}
        due = (now_dt + datetime.timedelta(days=cadence[0])).isoformat(timespec="seconds")
        now_iso = now_dt.isoformat(timespec="seconds")
        conn.execute("""INSERT INTO user_graph_review_schedule
            (custom_id,frequency,cadence_json,sequence_index,last_reviewed_at,next_due_at,
             review_count,active,created_at,updated_at) VALUES (?,?,?,?,NULL,?,0,1,?,?)""",
            (custom_id, freq, json.dumps(cadence), 0, due, now_iso, now_iso))
        _event(conn, custom_id, "REGISTERED", freq, 0, due,
               {"cadence_days": cadence, "scheduling_version": SCHEDULING_VERSION}, now_iso)
        conn.commit()
        return {"custom_id": custom_id, "title": graph["title"], "frequency": freq,
                "cadence_days": cadence, "sequence_index": 0, "next_due_at": due,
                "review_count": 0, "active": 1, "created": True,
                "scheduling_version": SCHEDULING_VERSION}
    finally:
        try:
            conn.close()
        except Exception:
            pass


def list_schedules(due_only: bool = False, now_dt: datetime.datetime | None = None,
                   limit: int = 50, scheduler_path: str | None = None,
                   graph_db_path: str | None = None) -> list[dict]:
    now_iso = _now(now_dt).isoformat(timespec="seconds")
    conn = db.connect(scheduler_path or db.DB_SCHEDULER, init=True)
    try:
        conn.execute("ATTACH DATABASE ? AS graphdb", (_graph_db_path(graph_db_path),))
        where = "AND s.next_due_at<=?" if due_only else ""
        params = (now_iso, max(1, limit)) if due_only else (max(1, limit),)
        rows = conn.execute(f"""SELECT s.*,g.graph_id,n.title,n.body_markdown,
            CASE WHEN s.next_due_at<=? THEN 1 ELSE 0 END AS due
            FROM user_graph_review_schedule s
            JOIN graphdb.graphs g ON g.source_id=s.custom_id AND g.question_source='USER_AUTHORED'
            JOIN graphdb.nodes n ON n.node_id=g.center_node_id
            WHERE s.active=1 {where}
            ORDER BY s.next_due_at,s.created_at LIMIT ?""",
            ((now_iso,) + params)).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


def mark_shown(custom_id: str, now_dt: datetime.datetime | None = None,
               scheduler_path: str | None = None) -> dict:
    now_iso = _now(now_dt).isoformat(timespec="seconds")
    conn = db.connect(scheduler_path or db.DB_SCHEDULER, init=True)
    try:
        row = conn.execute("SELECT * FROM user_graph_review_schedule WHERE custom_id=?", (custom_id,)).fetchone()
        if not row:
            raise ValueError(f"自拟问题图尚未登记调度: {custom_id}")
        _event(conn, custom_id, "REVIEW_SHOWN", row["frequency"], row["sequence_index"],
               row["next_due_at"], occurred_at=now_iso)
        conn.commit()
        return {"custom_id": custom_id, "shown_at": now_iso, "next_due_at": row["next_due_at"]}
    finally:
        conn.close()


def complete(custom_id: str, now_dt: datetime.datetime | None = None,
             scheduler_path: str | None = None) -> dict:
    now_dt = _now(now_dt)
    now_iso = now_dt.isoformat(timespec="seconds")
    conn = db.connect(scheduler_path or db.DB_SCHEDULER, init=True)
    try:
        row = conn.execute("SELECT * FROM user_graph_review_schedule WHERE custom_id=? AND active=1", (custom_id,)).fetchone()
        if not row:
            raise ValueError(f"找不到活动的自拟图调度: {custom_id}")
        cadence = json.loads(row["cadence_json"])
        next_index = min(row["sequence_index"] + 1, len(cadence) - 1)
        interval = cadence[next_index]
        next_due = (now_dt + datetime.timedelta(days=interval)).isoformat(timespec="seconds")
        conn.execute("""UPDATE user_graph_review_schedule SET sequence_index=?,last_reviewed_at=?,
            next_due_at=?,review_count=review_count+1,updated_at=? WHERE custom_id=?""",
            (next_index, now_iso, next_due, now_iso, custom_id))
        _event(conn, custom_id, "REVIEW_COMPLETED", row["frequency"], next_index, next_due,
               {"previous_due_at": row["next_due_at"], "interval_days": interval}, now_iso)
        conn.commit()
        return {"custom_id": custom_id, "frequency": row["frequency"],
                "sequence_index": next_index, "interval_days": interval,
                "next_due_at": next_due, "review_count": row["review_count"] + 1}
    finally:
        conn.close()


def set_frequency(custom_id: str, frequency: str, now_dt: datetime.datetime | None = None,
                  scheduler_path: str | None = None, graph_db_path: str | None = None) -> dict:
    _assert_user_graph(custom_id, graph_db_path)
    freq = _frequency(frequency)
    cadence = CADENCES[freq]
    now_dt = _now(now_dt)
    now_iso = now_dt.isoformat(timespec="seconds")
    conn = db.connect(scheduler_path or db.DB_SCHEDULER, init=True)
    try:
        row = conn.execute("SELECT * FROM user_graph_review_schedule WHERE custom_id=?", (custom_id,)).fetchone()
        if not row:
            conn.close()
            return register(custom_id, freq, now_dt=now_dt, scheduler_path=scheduler_path,
                            graph_db_path=graph_db_path)
        new_index = min(row["review_count"], len(cadence) - 1)
        interval = cadence[new_index]
        next_due = (now_dt + datetime.timedelta(days=interval)).isoformat(timespec="seconds")
        conn.execute("""UPDATE user_graph_review_schedule SET frequency=?,cadence_json=?,sequence_index=?,
            next_due_at=?,active=1,updated_at=? WHERE custom_id=?""",
            (freq, json.dumps(cadence), new_index, next_due, now_iso, custom_id))
        _event(conn, custom_id, "FREQUENCY_CHANGED", freq, new_index, next_due,
               {"previous_frequency": row["frequency"], "interval_days": interval}, now_iso)
        conn.commit()
        return {"custom_id": custom_id, "frequency": freq, "cadence_days": cadence,
                "sequence_index": new_index, "next_due_at": next_due,
                "review_count": row["review_count"], "active": 1}
    finally:
        try:
            conn.close()
        except Exception:
            pass
