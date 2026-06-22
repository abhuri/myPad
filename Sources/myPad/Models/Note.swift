import Foundation

struct Note: Codable, Equatable, Identifiable {
    var id: UUID
    var content: String
    var filePath: String?
    var customTitle: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        content: String = "",
        filePath: String? = nil,
        customTitle: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.filePath = filePath
        self.customTitle = customTitle
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var title: String {
        if let customTitle = customTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !customTitle.isEmpty {
            return customTitle
        }

        let firstLine = content
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !firstLine.isEmpty else {
            return fileDisplayName ?? "Untitled"
        }

        if firstLine.count <= 36 {
            return firstLine
        }

        return String(firstLine.prefix(33)) + "..."
    }

    var fileDisplayName: String? {
        guard let filePath, !filePath.isEmpty else {
            return nil
        }

        return URL(fileURLWithPath: filePath).lastPathComponent
    }

    var characterCount: Int {
        content.count
    }

    var wordCount: Int {
        content
            .split { character in
                character.isWhitespace || character.isNewline
            }
            .count
    }

    var estimatedReadMinutes: Int {
        guard wordCount > 0 else {
            return 0
        }

        return max(1, Int(ceil(Double(wordCount) / 200)))
    }

    var lineCount: Int {
        content.isEmpty ? 1 : content.components(separatedBy: .newlines).count
    }
}
