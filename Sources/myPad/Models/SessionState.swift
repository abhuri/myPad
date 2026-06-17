import Foundation

struct SessionState: Codable {
    var notes: [Note]
    var selectedNoteID: UUID?
    var settings: EditorSettings
}
