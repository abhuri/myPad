import Foundation

struct Note: Codable, Equatable, Identifiable {
    var id: UUID
    var content: String
    var filePath: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        content: String = "",
        filePath: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.filePath = filePath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var title: String {
        let firstLine = content
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !firstLine.isEmpty else {
            return "Untitled"
        }

        if firstLine.count <= 36 {
            return firstLine
        }

        return String(firstLine.prefix(33)) + "..."
    }

    var characterCount: Int {
        content.count
    }

    var lineCount: Int {
        content.isEmpty ? 1 : content.components(separatedBy: .newlines).count
    }
}
