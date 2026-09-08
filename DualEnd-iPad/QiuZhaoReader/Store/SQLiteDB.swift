// SQLite 薄封装 —— iPad 本地 durable（系统 SQLite3 C API, 零第三方）。
import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum SQLiteError: Error {
    case open(String)
    case prepare(String)
    case step(String)
}

/// 每连接单线程使用（ClientStore actor 内串行）
final class SQLiteDB {
    private var handle: OpaquePointer?
    let path: String

    init?(path: String) {
        self.path = path
        var h: OpaquePointer?
        guard sqlite3_open(path, &h) == SQLITE_OK, let h else { return nil }
        handle = h
        sqlite3_exec(h, "PRAGMA foreign_keys=ON; PRAGMA journal_mode=WAL;", nil, nil, nil)
    }

    /// 多语句 DDL/DML 直接走 sqlite3_exec（单语句 prepare/step 只执行第一条）
    func exec(_ sql: String, _ binds: [Any?] = []) throws {
        if binds.isEmpty {
            var errMsg: UnsafeMutablePointer<CChar>?
            let rc = sqlite3_exec(handle, sql, nil, nil, &errMsg)
            if rc != SQLITE_OK {
                let msg = errMsg.map { String(cString: $0) } ?? "unknown"
                sqlite3_free(errMsg)
                throw SQLiteError.step(msg)
            }
            return
        }
        let stmt = try prepare(sql, binds)
        let rc = sqlite3_step(stmt)
        sqlite3_finalize(stmt)
        if rc != SQLITE_DONE && rc != SQLITE_ROW {
            throw SQLiteError.step(String(cString: sqlite3_errmsg(handle)))
        }
    }

    /// 通用查询: SELECT -> [[String: Any]]
    func query(_ sql: String, _ binds: [Any?] = []) throws -> [[String: Any]] {
        let stmt = try prepare(sql, binds)
        defer { sqlite3_finalize(stmt) }
        var rows: [[String: Any]] = []
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_ROW {
                var row: [String: Any] = [:]
                for i in 0..<sqlite3_column_count(stmt) {
                    let name = String(cString: sqlite3_column_name(stmt, i))
                    switch sqlite3_column_type(stmt, i) {
                    case SQLITE_INTEGER: row[name] = sqlite3_column_int64(stmt, i)
                    case SQLITE_FLOAT: row[name] = sqlite3_column_double(stmt, i)
                    case SQLITE_TEXT: row[name] = String(cString: sqlite3_column_text(stmt, i))
                    case SQLITE_BLOB:
                        if let b = sqlite3_column_blob(stmt, i) {
                            row[name] = Data(bytes: b, count: Int(sqlite3_column_bytes(stmt, i)))
                        }
                    default: row[name] = NSNull()
                    }
                }
                rows.append(row)
            } else if rc == SQLITE_DONE {
                break
            } else {
                throw SQLiteError.step(String(cString: sqlite3_errmsg(handle)))
            }
        }
        return rows
    }

    func prepare(_ sql: String, _ binds: [Any?]) throws -> OpaquePointer {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw SQLiteError.prepare(String(cString: sqlite3_errmsg(handle)))
        }
        for (i, b) in binds.enumerated() {
            let idx = Int32(i + 1)
            if let s = b as? String { sqlite3_bind_text(stmt, idx, s, -1, SQLITE_TRANSIENT) }
            else if let n = b as? Int64 { sqlite3_bind_int64(stmt, idx, n) }
            else if let n = b as? Int { sqlite3_bind_int64(stmt, idx, Int64(n)) }
            else if let d = b as? Double { sqlite3_bind_double(stmt, idx, d) }
            else if let d = b as? Data {
                d.withUnsafeBytes { sqlite3_bind_blob(stmt, idx, $0.baseAddress, Int32(d.count), SQLITE_TRANSIENT) }
            } else if b == nil || b is NSNull { sqlite3_bind_null(stmt, idx) }
            else { fatalError("unsupported bind") }
        }
        return stmt
    }

    func begin() { sqlite3_exec(handle, "BEGIN IMMEDIATE", nil, nil, nil) }
    func commit() { sqlite3_exec(handle, "COMMIT", nil, nil, nil) }
    func rollback() { sqlite3_exec(handle, "ROLLBACK", nil, nil, nil) }

    deinit { sqlite3_close(handle) }
}
