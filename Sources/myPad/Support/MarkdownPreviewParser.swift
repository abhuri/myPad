import Foundation

enum MarkdownPreviewParser {
    static func parse(_ text: String) -> [MarkdownBlock] {
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        var blocks: [MarkdownBlock] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                index += 1
                continue
            }

            if let codeBlock = parseCodeBlock(lines: lines, startIndex: index) {
                blocks.append(.code(language: codeBlock.language, text: codeBlock.text))
                index = codeBlock.nextIndex
                continue
            }

            if let table = parseTable(lines: lines, startIndex: index) {
                blocks.append(.table(table))
                index = table.nextIndex
                continue
            }

            if let heading = parseHeading(trimmed) {
                blocks.append(.heading(level: heading.level, text: heading.text))
                index += 1
                continue
            }

            if let image = parseImage(trimmed) {
                blocks.append(.image(altText: image.altText, source: image.source))
                index += 1
                continue
            }

            if isHorizontalRule(trimmed) {
                blocks.append(.horizontalRule)
                index += 1
                continue
            }

            if trimmed.hasPrefix(">") {
                let quote = parseBlockquote(lines: lines, startIndex: index)
                blocks.append(.blockquote(quote.text))
                index = quote.nextIndex
                continue
            }

            if let list = parseList(lines: lines, startIndex: index) {
                blocks.append(list.block)
                index = list.nextIndex
                continue
            }

            let paragraph = parseParagraph(lines: lines, startIndex: index)
            blocks.append(.paragraph(paragraph.text))
            index = paragraph.nextIndex
        }

        return blocks
    }
}

enum MarkdownBlock {
    case heading(level: Int, text: String)
    case paragraph(String)
    case blockquote(String)
    case unorderedList([MarkdownListItem])
    case orderedList([MarkdownListItem])
    case code(language: String?, text: String)
    case table(MarkdownTableBlock)
    case image(altText: String, source: String)
    case horizontalRule
}

struct MarkdownListItem {
    var text: String
    var depth: Int
    var marker: Marker
    var taskState: TaskState?

    enum Marker {
        case bullet
        case ordered(String)
        case task
    }

    enum TaskState {
        case unchecked
        case checked
    }
}

struct MarkdownTableBlock {
    var headers: [String]
    var rows: [[String]]
    var alignments: [MarkdownTableFormatter.ColumnAlignment]
    var nextIndex: Int = 0
}

private extension MarkdownPreviewParser {
    static func parseCodeBlock(lines: [String], startIndex: Int) -> (language: String?, text: String, nextIndex: Int)? {
        let opening = lines[startIndex].trimmingCharacters(in: .whitespaces)
        let fence: String

        if opening.hasPrefix("```") {
            fence = "```"
        } else if opening.hasPrefix("~~~") {
            fence = "~~~"
        } else {
            return nil
        }

        let language = opening.dropFirst(fence.count)
            .trimmingCharacters(in: .whitespaces)
            .nilIfEmpty
        var codeLines: [String] = []
        var index = startIndex + 1

        while index < lines.count {
            let line = lines[index]

            if line.trimmingCharacters(in: .whitespaces).hasPrefix(fence) {
                return (language, codeLines.joined(separator: "\n"), index + 1)
            }

            codeLines.append(line)
            index += 1
        }

        return (language, codeLines.joined(separator: "\n"), index)
    }

    static func parseTable(lines: [String], startIndex: Int) -> MarkdownTableBlock? {
        guard startIndex + 1 < lines.count,
              lines[startIndex].contains("|"),
              let alignments = separatorAlignments(in: lines[startIndex + 1]) else {
            return nil
        }

        let headers = parsePipeLine(lines[startIndex]).map(cleanCell)
        guard headers.count > 1 else {
            return nil
        }

        var rows: [[String]] = []
        var index = startIndex + 2

        while index < lines.count, lines[index].contains("|") {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)

            guard !trimmed.isEmpty, separatorAlignments(in: trimmed) == nil else {
                break
            }

            rows.append(parsePipeLine(lines[index]).map(cleanCell))
            index += 1
        }

        return MarkdownTableBlock(headers: headers, rows: rows, alignments: alignments, nextIndex: index)
    }

    static func parseHeading(_ trimmed: String) -> (level: Int, text: String)? {
        var level = 0

        for character in trimmed {
            if character == "#", level < 6 {
                level += 1
            } else {
                break
            }
        }

        guard level > 0,
              trimmed.dropFirst(level).first == " " else {
            return nil
        }

        let text = trimmed.dropFirst(level)
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#").union(.whitespaces))
        return (level, text)
    }

    static func parseImage(_ trimmed: String) -> (altText: String, source: String)? {
        guard trimmed.hasPrefix("!["),
              let altEnd = trimmed.firstIndex(of: "]") else {
            return nil
        }

        let afterAlt = trimmed.index(after: altEnd)
        guard afterAlt < trimmed.endIndex,
              trimmed[afterAlt] == "(",
              trimmed.hasSuffix(")") else {
            return nil
        }

        let sourceStart = trimmed.index(after: afterAlt)
        let sourceEnd = trimmed.index(before: trimmed.endIndex)
        let altText = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 2)..<altEnd])
        let source = String(trimmed[sourceStart..<sourceEnd])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !source.isEmpty else {
            return nil
        }

        return (altText, source)
    }

    static func isHorizontalRule(_ trimmed: String) -> Bool {
        let compact = trimmed.filter { !$0.isWhitespace }
        guard compact.count >= 3 else {
            return false
        }

        return compact.allSatisfy { $0 == "-" }
            || compact.allSatisfy { $0 == "*" }
            || compact.allSatisfy { $0 == "_" }
    }

    static func parseBlockquote(lines: [String], startIndex: Int) -> (text: String, nextIndex: Int) {
        var quoteLines: [String] = []
        var index = startIndex

        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix(">") else {
                break
            }

            quoteLines.append(
                trimmed
                    .dropFirst()
                    .trimmingCharacters(in: .whitespaces)
            )
            index += 1
        }

        return (quoteLines.joined(separator: "\n"), index)
    }

    static func parseList(lines: [String], startIndex: Int) -> (block: MarkdownBlock, nextIndex: Int)? {
        guard let first = parseListItem(lines[startIndex]) else {
            return nil
        }

        var items = [first]
        var index = startIndex + 1

        while index < lines.count, let item = parseListItem(lines[index]) {
            items.append(item)
            index += 1
        }

        let isOrdered = items.first?.marker.isOrdered == true
        return (isOrdered ? .orderedList(items) : .unorderedList(items), index)
    }

    static func parseListItem(_ line: String) -> MarkdownListItem? {
        parseUnorderedListItem(line) ?? parseOrderedListItem(line)
    }

    static func parseUnorderedListItem(_ line: String) -> MarkdownListItem? {
        let indent = leadingIndent(in: line)
        let depth = listDepth(from: indent)
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let markers = ["- ", "* ", "+ ", "• "]
        let body: String

        if let marker = markers.first(where: { trimmed.hasPrefix($0) }) {
            body = String(trimmed.dropFirst(marker.count))
        } else if trimmed.hasPrefix("[ ] ") || trimmed.hasPrefix("[x] ") || trimmed.hasPrefix("[X] ") {
            body = trimmed
        } else {
            return nil
        }

        if body.hasPrefix("[ ] ") {
            return MarkdownListItem(text: String(body.dropFirst(4)), depth: depth, marker: .task, taskState: .unchecked)
        }

        if body.hasPrefix("[x] ") || body.hasPrefix("[X] ") {
            return MarkdownListItem(text: String(body.dropFirst(4)), depth: depth, marker: .task, taskState: .checked)
        }

        return MarkdownListItem(text: body, depth: depth, marker: .bullet, taskState: nil)
    }

    static func parseOrderedListItem(_ line: String) -> MarkdownListItem? {
        let indent = leadingIndent(in: line)
        let depth = listDepth(from: indent)
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        var index = trimmed.startIndex
        var numberPath: [String] = []

        while index < trimmed.endIndex {
            let numberStart = index

            while index < trimmed.endIndex, trimmed[index].isNumber {
                index = trimmed.index(after: index)
            }

            guard numberStart < index,
                  index < trimmed.endIndex else {
                return nil
            }

            numberPath.append(String(trimmed[numberStart..<index]))
            let punctuation = trimmed[index]

            guard punctuation == "." || (punctuation == ")" && numberPath.count == 1) else {
                return nil
            }

            index = trimmed.index(after: index)

            if index < trimmed.endIndex, trimmed[index] == " " {
                let bodyStart = trimmed.index(after: index)
                let markerText = numberPath.joined(separator: ".") + "."
                return MarkdownListItem(
                    text: String(trimmed[bodyStart...]),
                    depth: max(depth, max(0, numberPath.count - 1)),
                    marker: .ordered(markerText),
                    taskState: nil
                )
            }

            guard punctuation == ".", index < trimmed.endIndex, trimmed[index].isNumber else {
                return nil
            }
        }

        return nil
    }

    static func parseParagraph(lines: [String], startIndex: Int) -> (text: String, nextIndex: Int) {
        var paragraphLines: [String] = []
        var index = startIndex

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty || startsNewBlock(lines: lines, index: index, allowCurrentParagraph: !paragraphLines.isEmpty) {
                break
            }

            paragraphLines.append(trimmed)
            index += 1
        }

        return (paragraphLines.joined(separator: "\n"), max(index, startIndex + 1))
    }

    static func startsNewBlock(lines: [String], index: Int, allowCurrentParagraph: Bool) -> Bool {
        guard allowCurrentParagraph else {
            return false
        }

        let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
        return parseHeading(trimmed) != nil
            || isHorizontalRule(trimmed)
            || trimmed.hasPrefix(">")
            || trimmed.hasPrefix("```")
            || trimmed.hasPrefix("~~~")
            || parseImage(trimmed) != nil
            || parseListItem(lines[index]) != nil
            || (index + 1 < lines.count && lines[index].contains("|") && separatorAlignments(in: lines[index + 1]) != nil)
    }

    static func parsePipeLine(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("|") {
            trimmed.removeFirst()
        }

        if trimmed.hasSuffix("|") {
            trimmed.removeLast()
        }

        var cells: [String] = []
        var current = ""
        var isEscaped = false

        for character in trimmed {
            if isEscaped {
                current.append(character)
                isEscaped = false
            } else if character == "\\" {
                isEscaped = true
            } else if character == "|" {
                cells.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }

        if isEscaped {
            current.append("\\")
        }

        cells.append(current)
        return cells
    }

    static func separatorAlignments(in line: String) -> [MarkdownTableFormatter.ColumnAlignment]? {
        let cells = parsePipeLine(line)
        guard !cells.isEmpty else {
            return nil
        }

        var alignments: [MarkdownTableFormatter.ColumnAlignment] = []

        for cell in cells {
            let trimmed = cell.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                return nil
            }

            let hasLeadingColon = trimmed.hasPrefix(":")
            let hasTrailingColon = trimmed.hasSuffix(":")
            var marker = trimmed

            if hasLeadingColon {
                marker.removeFirst()
            }

            if hasTrailingColon, !marker.isEmpty {
                marker.removeLast()
            }

            guard marker.count >= 3, marker.allSatisfy({ $0 == "-" }) else {
                return nil
            }

            if hasLeadingColon && hasTrailingColon {
                alignments.append(.center)
            } else if hasLeadingColon {
                alignments.append(.left)
            } else if hasTrailingColon {
                alignments.append(.right)
            } else {
                alignments.append(.none)
            }
        }

        return alignments
    }

    static func cleanCell(_ cell: String) -> String {
        cell.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private extension MarkdownListItem.Marker {
    var isOrdered: Bool {
        if case .ordered = self {
            return true
        }

        return false
    }
}

private extension MarkdownPreviewParser {
    static func leadingIndent(in line: String) -> String {
        let end = line.firstIndex { character in
            character != " " && character != "\t"
        } ?? line.endIndex
        return String(line[..<end])
    }

    static func listDepth(from indent: String) -> Int {
        var depth = 0
        var spaces = 0

        for character in indent {
            if character == "\t" {
                depth += 1
                spaces = 0
            } else if character == " " {
                spaces += 1
                if spaces == 3 || spaces == 4 {
                    depth += 1
                    spaces = 0
                }
            }
        }

        if spaces > 0 {
            depth += 1
        }

        return depth
    }
}
