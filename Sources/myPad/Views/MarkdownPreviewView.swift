import AppKit
import SwiftUI

struct MarkdownPreviewView: View {
    var text: String
    var settings: EditorSettings
    var baseURL: URL?
    var scrollProgress: Double = 0
    var scrollSource: EditorScrollSyncSource = .editor
    var onScrollProgressChange: (Double) -> Void = { _ in }

    private var blocks: [MarkdownBlock] {
        MarkdownPreviewParser.parse(text)
    }

    var body: some View {
        Group {
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ContentUnavailableView("Nothing to Preview", systemImage: "doc.richtext")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                SyncedScrollView(
                    scrollProgress: scrollProgress,
                    scrollSource: scrollSource,
                    selfSource: .preview,
                    onScrollProgressChange: onScrollProgressChange
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                            blockView(block)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 24)
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            headingView(level: level, text: text)
        case .paragraph(let text):
            inlineText(text)
                .font(.system(size: bodyFontSize))
                .lineSpacing(4)
                .textSelection(.enabled)
        case .blockquote(let text):
            HStack(alignment: .top, spacing: 10) {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 3)

                inlineText(text)
                    .font(.system(size: bodyFontSize))
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
                    .textSelection(.enabled)
            }
            .padding(.vertical, 2)
        case .unorderedList(let items):
            listView(items: items)
        case .orderedList(let items):
            listView(items: items)
        case .code(let language, let text):
            codeBlock(language: language, text: text)
        case .table(let table):
            tableView(table)
        case .image(let altText, let source):
            imageView(altText: altText, source: source)
        case .horizontalRule:
            Divider()
                .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func imageView(altText: String, source: String) -> some View {
        if let url = resolvedImageURL(source) {
            if url.isFileURL {
                if let image = NSImage(contentsOf: url) {
                    VStack(alignment: .leading, spacing: 6) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        if !altText.isEmpty {
                            Text(altText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    missingImageView(source: source)
                }
            } else {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 120)
                    case .success(let image):
                        VStack(alignment: .leading, spacing: 6) {
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                            if !altText.isEmpty {
                                Text(altText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    case .failure:
                        missingImageView(source: source)
                    @unknown default:
                        missingImageView(source: source)
                    }
                }
            }
        } else {
            missingImageView(source: source)
        }
    }

    private func missingImageView(source: String) -> some View {
        Label(source, systemImage: "photo")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func headingView(level: Int, text: String) -> some View {
        let fontSize = headingFontSize(for: level)

        VStack(alignment: .leading, spacing: level <= 2 ? 8 : 0) {
            inlineText(text)
                .font(.system(size: fontSize, weight: .semibold))
                .lineLimit(nil)
                .textSelection(.enabled)

            if level <= 2 {
                Divider()
            }
        }
        .padding(.top, level == 1 ? 4 : 8)
    }

    private func listView(items: [MarkdownListItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let taskState = item.taskState {
                        Image(systemName: taskState == .checked ? "checkmark.square.fill" : "square")
                            .foregroundStyle(taskState == .checked ? Color.accentColor : Color.secondary)
                            .frame(width: 18, alignment: .trailing)
                    } else {
                        Text(listMarkerText(for: item))
                            .font(.system(size: bodyFontSize, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: markerWidth(for: item), alignment: .trailing)
                    }

                    inlineText(item.text)
                        .font(.system(size: bodyFontSize))
                        .lineSpacing(4)
                        .textSelection(.enabled)
                }
                .padding(.leading, CGFloat(max(0, item.depth)) * 28)
            }
        }
        .padding(.leading, 6)
    }

    private func listMarkerText(for item: MarkdownListItem) -> String {
        switch item.marker {
        case .bullet, .task:
            return "•"
        case .ordered(let marker):
            return marker
        }
    }

    private func markerWidth(for item: MarkdownListItem) -> CGFloat {
        if case .ordered(let marker) = item.marker {
            return max(28, CGFloat(marker.count) * max(7, bodyFontSize * 0.5) + 8)
        }

        return 28
    }

    private func codeBlock(language: String?, text: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language {
                Text(language)
                    .font(.system(size: max(10, bodyFontSize - 3), weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
            }

            ScrollView(.horizontal) {
                Text(text.isEmpty ? " " : text)
                    .font(.system(size: max(10, bodyFontSize - 1), design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .separatorColor).opacity(0.6))
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func tableView(_ table: MarkdownTableBlock) -> some View {
        let columnCount = max(1, ([table.headers.count, table.alignments.count] + table.rows.map(\.count)).max() ?? 1)
        let headers = normalizedRow(table.headers, count: columnCount)
        let rows = table.rows.map { normalizedRow($0, count: columnCount) }
        let alignments = (0..<columnCount).map { index in
            index < table.alignments.count ? table.alignments[index] : .none
        }
        let columnWidths = tableColumnWidths(headers: headers, rows: rows)

        return ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 0) {
                tableRow(
                    headers,
                    isHeader: true,
                    rowIndex: 0,
                    rowCount: rows.count + 1,
                    alignments: alignments,
                    columnWidths: columnWidths
                )
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    tableRow(
                        row,
                        isHeader: false,
                        rowIndex: rowIndex + 1,
                        rowCount: rows.count + 1,
                        alignments: alignments,
                        columnWidths: columnWidths
                    )
                    .background(rowIndex.isMultiple(of: 2) ? Color.clear : Color(nsColor: .controlBackgroundColor).opacity(0.28))
                }
            }
            .font(.system(size: max(11, bodyFontSize - 1)))
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func tableRow(
        _ row: [String],
        isHeader: Bool,
        rowIndex: Int,
        rowCount: Int,
        alignments: [MarkdownTableFormatter.ColumnAlignment],
        columnWidths: [CGFloat]
    ) -> some View {
        HStack(spacing: 0) {
            ForEach(row.indices, id: \.self) { columnIndex in
                tableCell(
                    row[columnIndex],
                    isHeader: isHeader,
                    alignment: alignments[columnIndex],
                    width: columnWidths[columnIndex],
                    rowIndex: rowIndex,
                    columnIndex: columnIndex,
                    rowCount: rowCount,
                    columnCount: row.count
                )
            }
        }
    }

    private func tableCell(
        _ text: String,
        isHeader: Bool,
        alignment: MarkdownTableFormatter.ColumnAlignment,
        width: CGFloat,
        rowIndex: Int,
        columnIndex: Int,
        rowCount: Int,
        columnCount: Int
    ) -> some View {
        inlineText(text.isEmpty ? " " : text)
            .fontWeight(isHeader ? .semibold : .regular)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(width: width, alignment: alignment.swiftUIAlignment)
            .frame(minHeight: 32)
            .background(isHeader ? Color(nsColor: .controlBackgroundColor).opacity(0.85) : Color.clear)
            .overlay(
                TableCellBorder(
                    rowIndex: rowIndex,
                    columnIndex: columnIndex,
                    rowCount: rowCount,
                    columnCount: columnCount
                )
            )
            .textSelection(.enabled)
    }

    private func tableColumnWidths(headers: [String], rows: [[String]]) -> [CGFloat] {
        let allRows = [headers] + rows
        let minimumWidth: CGFloat = 96
        let maximumWidth: CGFloat = 520
        let characterWidth = max(7, bodyFontSize * 0.58)

        return headers.indices.map { columnIndex in
            let widestCharacterCount = allRows
                .compactMap { row in
                    columnIndex < row.count ? row[columnIndex].count : nil
                }
                .max() ?? 0
            let estimatedWidth = CGFloat(widestCharacterCount) * characterWidth + 24
            return max(minimumWidth, min(maximumWidth, ceil(estimatedWidth)))
        }
    }

    private func normalizedRow(_ row: [String], count: Int) -> [String] {
        (0..<count).map { index in
            index < row.count ? row[index] : ""
        }
    }

    private func inlineText(_ text: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)

        if let attributed = try? AttributedString(markdown: text, options: options) {
            return Text(attributed)
        }

        return Text(text)
    }

    private func resolvedImageURL(_ source: String) -> URL? {
        if let url = URL(string: source), url.scheme != nil {
            return url
        }

        if source.hasPrefix("/") {
            return URL(fileURLWithPath: source)
        }

        guard let baseURL else {
            return nil
        }

        return baseURL.appendingPathComponent(source)
    }

    private var bodyFontSize: CGFloat {
        max(11, settings.effectiveFontSize)
    }

    private func headingFontSize(for level: Int) -> CGFloat {
        let scale: CGFloat

        switch level {
        case 1:
            scale = 1.9
        case 2:
            scale = 1.55
        case 3:
            scale = 1.3
        case 4:
            scale = 1.12
        default:
            scale = 1
        }

        return max(bodyFontSize, min(48, bodyFontSize * scale))
    }
}

private struct TableCellBorder: View {
    var rowIndex: Int
    var columnIndex: Int
    var rowCount: Int
    var columnCount: Int

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let inset: CGFloat = 0.5

                path.move(to: CGPoint(x: inset, y: inset))
                path.addLine(to: CGPoint(x: width - inset, y: inset))

                path.move(to: CGPoint(x: inset, y: inset))
                path.addLine(to: CGPoint(x: inset, y: height - inset))

                if columnIndex == columnCount - 1 {
                    path.move(to: CGPoint(x: width - inset, y: inset))
                    path.addLine(to: CGPoint(x: width - inset, y: height - inset))
                }

                if rowIndex == rowCount - 1 {
                    path.move(to: CGPoint(x: inset, y: height - inset))
                    path.addLine(to: CGPoint(x: width - inset, y: height - inset))
                }
            }
            .stroke(Color(nsColor: .separatorColor).opacity(0.92), lineWidth: 1.725)
        }
        .allowsHitTesting(false)
    }
}

private extension MarkdownTableFormatter.ColumnAlignment {
    var swiftUIAlignment: Alignment {
        switch self {
        case .none, .left:
            return .leading
        case .center:
            return .center
        case .right:
            return .trailing
        }
    }
}
