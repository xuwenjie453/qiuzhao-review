// MarkdownRenderer —— 自建 block parser + UIKit 渲染（支持秋招解释常见语法）。
// 不引入 WebView 作为默认实现(坐标稳定)。body immutable ⇒ 布局坐标是 Ink 稳定底纸。
import UIKit

enum MDBlock {
    case heading(Int, String)
    case paragraph(String)
    case list(String)          // 已带 "- "/"1. " 前缀的项
    case code(String)
    case quote(String)
    case hr
    case table(headers: [String], rows: [[String]])
}

enum MarkdownParser {
    static func parse(_ md: String) -> [MDBlock] {
        var blocks: [MDBlock] = []
        var lines = md.components(separatedBy: "\n").map { String($0) }
        var i = 0
        var pendingFence: [String] = []
        var inFence = false
        var pendingTable: [String] = []
        func flushTable() {
            guard pendingTable.count >= 2 else { pendingTable.removeAll(); return }
            let header = splitRow(pendingTable[0])
            let rows = pendingTable.dropFirst().filter { !isSepRow($0) }.map { splitRow($0) }
            blocks.append(.table(headers: header, rows: rows))
            pendingTable.removeAll()
        }
        func flushList(_ items: [String]) {
            for it in items { blocks.append(.list(it)) }
        }
        while i < lines.count {
            var ln = lines[i]
            let trimmed = ln.trimmingCharacters(in: .whitespaces)
            if inFence {
                if trimmed.hasPrefix("```") { blocks.append(.code(pendingFence.joined(separator: "\n"))); pendingFence.removeAll(); inFence = false; i += 1; continue }
                pendingFence.append(ln); i += 1; continue
            }
            if trimmed.hasPrefix("```") { inFence = true; i += 1; continue }
            if trimmed == "---" || trimmed == "***" || trimmed == "___" { blocks.append(.hr); i += 1; continue }
            if trimmed.hasPrefix("#") {
                var level = 0
                while ln.hasPrefix("#") { level += 1; ln.removeFirst() }
                blocks.append(.heading(min(level, 3), ln.trimmingCharacters(in: .whitespaces)))
                i += 1; continue
            }
            if trimmed.hasPrefix(">") {
                var quote = ""
                while i < lines.count && lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                    quote += lines[i].trimmingCharacters(in: .whitespacesAndNewlines).dropFirst().trimmingCharacters(in: .whitespaces) + "\n"
                    i += 1
                }
                blocks.append(.quote(quote.trimmingCharacters(in: .newlines)))
                continue
            }
            if trimmed.hasPrefix("|") {
                pendingTable.append(trimmed)
                i += 1
                if i >= lines.count || !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("|") { flushTable() }
                continue
            }
            if !pendingTable.isEmpty { flushTable() }
            // 列表聚合
            if isListLine(trimmed) {
                var items: [String] = []
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    guard isListLine(t) else { break }
                    items.append(stripListMark(t))
                    i += 1
                }
                flushList(items)
                continue
            }
            if trimmed.isEmpty { i += 1; continue }
            blocks.append(.paragraph(inline(trimmed)))
            i += 1
        }
        if inFence { blocks.append(.code(pendingFence.joined(separator: "\n"))) }
        if !pendingTable.isEmpty { flushTable() }
        return blocks
    }

    private static func isListLine(_ s: String) -> Bool {
        s.hasPrefix("- ") || s.hasPrefix("* ") || s.hasPrefix("+ ") || s.hasPrefix("• ") ||
        (s.count > 2 && (s.first?.isNumber ?? false) && (s.dropFirst().first == "." || s.dropFirst().first == "）"))
    }
    private static func stripListMark(_ s: String) -> String {
        if s.hasPrefix("- ") || s.hasPrefix("* ") || s.hasPrefix("+ ") || s.hasPrefix("• ") { return String(s.dropFirst(2)) }
        if let dot = s.firstIndex(where: { $0 == "." || $0 == "）" }) { return String(s[s.index(after: dot)...]).trimmingCharacters(in: .whitespaces) }
        return s
    }
    private static func splitRow(_ s: String) -> [String] {
        var t = s
        if t.hasPrefix("|") { t.removeFirst() }
        if t.hasSuffix("|") { t.removeLast() }
        return t.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }
    private static func isSepRow(_ s: String) -> Bool {
        let body = s.replacingOccurrences(of: "|", with: "").trimmingCharacters(in: .whitespaces)
        return !body.isEmpty && body.allSatisfy { $0 == "-" || $0 == ":" || $0 == " " }
    }

    /// 行内标记简化: 剥除 ** * ` 记号保留文本(高保真富文本渲染为已知 v1 简化, 不影响坐标稳定性)
    static func inline(_ s: String) -> String {
        var out = s
        for token in ["**", "__", "`"] { out = out.replacingOccurrences(of: token, with: "") }
        out = out.replacingOccurrences(of: "*", with: "")
        return out
    }
}
