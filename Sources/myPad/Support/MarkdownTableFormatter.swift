import Foundation

enum MarkdownTableFormatter {
    static func makeTable(rows: Int, columns: Int) -> String {
        let rowCount = max(2, min(rows, 50))
        let columnCount = max(1, min(columns, 12))
        let header = (1...columnCount).map { "Column \($0)" }
        let body = Array(repeating: Array(repeating: "", count: columnCount), count: rowCount - 1)
        return formattedTable(header: header, body: body, alignments: Array(repeating: .none, count: columnCount))
    }

    static func convertDelimitedTextToTable(_ text: String) -> String? {
        let lines = normalizedLines(from: text)
        guard !lines.isEmpty, let delimiter = preferredDelimiter(for: lines) else {
            return nil
        }

        let parsedRows = lines.compactMap { line -> [String]? in
            switch delimiter {
            case .tab:
                return line.components(separatedBy: "\t").map(cleanCell)
            case .comma:
                return parseSeparatedLine(line, separator: ",").map(cleanCell)
            case .pipe:
                guard separatorAlignments(in: line) == nil else {
                    return nil
                }

                return parsePipeLine(line).map(cleanCell)
            }
        }
        .filter { !$0.isEmpty }

        guard parsedRows.contains(where: { $0.count > 1 }), let header = parsedRows.first else {
            return nil
        }

        let body = Array(parsedRows.dropFirst())
        return formattedTable(header: header, body: body, alignments: [])
    }

    static func formatTableBlock(_ block: String) -> String? {
        let lines = normalizedLines(from: block)
        guard !lines.isEmpty else {
            return nil
        }

        var rows: [[String]] = []
        var alignments: [ColumnAlignment] = []

        for line in lines {
            if let separatorAlignments = separatorAlignments(in: line) {
                alignments = separatorAlignments
                continue
            }

            let cells = parsePipeLine(line).map(cleanCell)
            guard !cells.isEmpty else {
                continue
            }

            rows.append(cells)
        }

        guard rows.contains(where: { $0.count > 1 }), let header = rows.first else {
            return nil
        }

        let body = Array(rows.dropFirst())
        return formattedTable(header: header, body: body, alignments: alignments)
    }

    static func formatTable(in text: String, selectedRange: NSRange) -> (range: NSRange, replacement: String)? {
        guard let range = tableBlockRange(in: text, selectedRange: selectedRange) else {
            return nil
        }

        let nsText = text as NSString
        guard let replacement = formatTableBlock(nsText.substring(with: range)) else {
            return nil
        }

        return (range, replacement)
    }

    static func firstHeaderRange(in table: String) -> NSRange? {
        let range = (table as NSString).range(of: "Column 1")
        return range.location == NSNotFound ? nil : range
    }
}

extension MarkdownTableFormatter {
    enum ColumnAlignment {
        case none
        case left
        case center
        case right
    }
}

private extension MarkdownTableFormatter {
    enum Delimiter {
        case tab
        case comma
        case pipe
    }

    struct LineInfo {
        var text: String
        var contentRange: NSRange
    }

    static func formattedTable(
        header: [String],
        body: [[String]],
        alignments: [ColumnAlignment]
    ) -> String {
        let columnCount = max(
            1,
            ([header.count, alignments.count] + body.map(\.count)).max() ?? 1
        )
        let normalizedHeader = normalizedRow(header, columnCount: columnCount, fallbackPrefix: "Column")
        let normalizedBody = body.isEmpty
            ? [Array(repeating: "", count: columnCount)]
            : body.map { normalizedRow($0, columnCount: columnCount, fallbackPrefix: "") }
        let normalizedAlignments = (0..<columnCount).map { index in
            index < alignments.count ? alignments[index] : .none
        }
        let widths = columnWidths(header: normalizedHeader, body: normalizedBody)

        var lines = [
            formattedRow(normalizedHeader, widths: widths),
            formattedSeparator(widths: widths, alignments: normalizedAlignments)
        ]
        lines.append(contentsOf: normalizedBody.map { formattedRow($0, widths: widths) })
        return lines.joined(separator: "\n")
    }

    static func normalizedRow(_ row: [String], columnCount: Int, fallbackPrefix: String) -> [String] {
        (0..<columnCount).map { index in
            if index < row.count, !row[index].isEmpty {
                return row[index]
            }

            guard !fallbackPrefix.isEmpty else {
                return ""
            }

            return "\(fallbackPrefix) \(index + 1)"
        }
    }

    static func columnWidths(header: [String], body: [[String]]) -> [Int] {
        (0..<header.count).map { index in
            let bodyWidth = body.map { displayWidth(of: $0[index]) }.max() ?? 0
            return max(3, displayWidth(of: header[index]), bodyWidth)
        }
    }

    static func formattedRow(_ row: [String], widths: [Int]) -> String {
        let cells = row.enumerated().map { index, cell in
            " " + padded(cell, to: widths[index]) + " "
        }
        return "|" + cells.joined(separator: "|") + "|"
    }

    static func formattedSeparator(widths: [Int], alignments: [ColumnAlignment]) -> String {
        let cells = widths.enumerated().map { index, width in
            " " + separatorMarker(width: width, alignment: alignments[index]) + " "
        }
        return "|" + cells.joined(separator: "|") + "|"
    }

    static func separatorMarker(width: Int, alignment: ColumnAlignment) -> String {
        let width = max(3, width)

        switch alignment {
        case .none:
            return String(repeating: "-", count: width)
        case .left:
            return ":" + String(repeating: "-", count: max(2, width - 1))
        case .right:
            return String(repeating: "-", count: max(2, width - 1)) + ":"
        case .center:
            return ":" + String(repeating: "-", count: max(1, width - 2)) + ":"
        }
    }

    static func padded(_ text: String, to width: Int) -> String {
        text + String(repeating: " ", count: max(0, width - displayWidth(of: text)))
    }

    static func displayWidth(of text: String) -> Int {
        text.count
    }

    static func normalizedLines(from text: String) -> [String] {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    static func preferredDelimiter(for lines: [String]) -> Delimiter? {
        if lines.contains(where: { $0.contains("\t") }) {
            return .tab
        }

        if lines.contains(where: { $0.contains("|") }) {
            return .pipe
        }

        if lines.contains(where: { $0.contains(",") }) {
            return .comma
        }

        return nil
    }

    static func cleanCell(_ cell: String) -> String {
        cell.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parseSeparatedLine(_ line: String, separator: Character) -> [String] {
        var cells: [String] = []
        var current = ""
        var isQuoted = false
        var iterator = line.makeIterator()

        while let character = iterator.next() {
            if character == "\"" {
                if isQuoted, let next = iterator.next() {
                    if next == "\"" {
                        current.append("\"")
                    } else {
                        isQuoted = false
                        if next == separator {
                            cells.append(current)
                            current = ""
                        } else {
                            current.append(next)
                        }
                    }
                } else {
                    isQuoted.toggle()
                }
            } else if character == separator, !isQuoted {
                cells.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }

        cells.append(current)
        return cells
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

    static func separatorAlignments(in line: String) -> [ColumnAlignment]? {
        let cells = parsePipeLine(line)
        guard !cells.isEmpty else {
            return nil
        }

        var alignments: [ColumnAlignment] = []

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

    static func tableBlockRange(in text: String, selectedRange: NSRange) -> NSRange? {
        let lines = lineInfos(in: text)
        guard !lines.isEmpty else {
            return nil
        }

        let nsText = text as NSString
        let selectedStart = max(0, min(selectedRange.location, nsText.length))
        let selectedEnd = max(selectedStart, min(NSMaxRange(selectedRange), nsText.length))
        guard let firstSelectedIndex = lineIndex(containing: selectedStart, in: lines),
              let lastSelectedIndex = lineIndex(containing: max(selectedStart, selectedEnd - 1), in: lines) else {
            return nil
        }

        let selectedTableIndices = (firstSelectedIndex...lastSelectedIndex).filter { isPotentialTableLine(lines[$0].text) }
        guard let firstTableIndex = selectedTableIndices.first,
              let lastTableIndex = selectedTableIndices.last else {
            return nil
        }

        guard !isInsideFencedCodeBlock(lines: lines, lineIndex: firstTableIndex) else {
            return nil
        }

        var lowerBound = firstTableIndex
        var upperBound = lastTableIndex

        while lowerBound > 0, isPotentialTableLine(lines[lowerBound - 1].text) {
            lowerBound -= 1
        }

        while upperBound + 1 < lines.count, isPotentialTableLine(lines[upperBound + 1].text) {
            upperBound += 1
        }

        let start = lines[lowerBound].contentRange.location
        let end = NSMaxRange(lines[upperBound].contentRange)
        return NSRange(location: start, length: max(0, end - start))
    }

    static func lineInfos(in text: String) -> [LineInfo] {
        let nsText = text as NSString
        guard nsText.length > 0 else {
            return [LineInfo(text: "", contentRange: NSRange(location: 0, length: 0))]
        }

        var lines: [LineInfo] = []
        var cursor = 0

        while cursor < nsText.length {
            var lineStart = 0
            var lineEnd = 0
            var contentsEnd = 0
            nsText.getLineStart(
                &lineStart,
                end: &lineEnd,
                contentsEnd: &contentsEnd,
                for: NSRange(location: cursor, length: 0)
            )

            let contentRange = NSRange(location: lineStart, length: contentsEnd - lineStart)
            lines.append(LineInfo(text: nsText.substring(with: contentRange), contentRange: contentRange))

            guard lineEnd > cursor else {
                break
            }

            cursor = lineEnd
        }

        if text.hasSuffix("\n") {
            lines.append(LineInfo(text: "", contentRange: NSRange(location: nsText.length, length: 0)))
        }

        return lines
    }

    static func lineIndex(containing location: Int, in lines: [LineInfo]) -> Int? {
        let target = max(0, location)

        for (index, line) in lines.enumerated() {
            let start = line.contentRange.location
            let end = NSMaxRange(line.contentRange)

            if target >= start, target <= end {
                return index
            }

            if index + 1 < lines.count, target > end, target < lines[index + 1].contentRange.location {
                return index
            }
        }

        return lines.indices.last
    }

    static func isPotentialTableLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && trimmed.contains("|")
    }

    static func isInsideFencedCodeBlock(lines: [LineInfo], lineIndex: Int) -> Bool {
        var openFence: String?

        for index in 0..<max(0, lineIndex) {
            let trimmed = lines[index].text.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                if openFence == "```" {
                    openFence = nil
                } else if openFence == nil {
                    openFence = "```"
                }
            } else if trimmed.hasPrefix("~~~") {
                if openFence == "~~~" {
                    openFence = nil
                } else if openFence == nil {
                    openFence = "~~~"
                }
            }
        }

        return openFence != nil
    }
}
