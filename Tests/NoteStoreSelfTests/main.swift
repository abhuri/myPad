import Foundation

@main
struct NoteStoreSelfTests {
    @MainActor
    static func main() throws {
        try createNoteSelectsNewTab()
        try closeSelectedNoteRemovesTabAndSelectsNeighbor()
        try sessionRestorePreservesSelectedNoteAndSettings()
        try sessionRestoreDropsDuplicateNoteIDs()
        print("NoteStore self-tests passed")
    }

    @MainActor
    private static func createNoteSelectsNewTab() throws {
        let directory = makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        let store = NoteStore(sessionDirectory: directory, observesTermination: false)
        store.ensureReady()

        let firstID = store.selectedNote?.id
        let note = store.createNote()

        try expect(store.notes.count == 2, "expected a new tab")
        try expect(store.selectedNote?.id == note.id, "expected new note to be selected")
        try expect(firstID != note.id, "expected a distinct note id")
    }

    @MainActor
    private static func closeSelectedNoteRemovesTabAndSelectsNeighbor() throws {
        let directory = makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        let store = NoteStore(sessionDirectory: directory, observesTermination: false)
        store.ensureReady()
        let firstID = store.selectedNote?.id
        let second = store.createNote()

        store.closeSelectedNote()

        try expect(store.notes.count == 1, "expected selected tab to close")
        try expect(store.selectedNote?.id == firstID, "expected previous tab to be selected")
        try expect(store.note(withID: second.id) == nil, "expected closed note to be removed")
    }

    @MainActor
    private static func sessionRestorePreservesSelectedNoteAndSettings() throws {
        let directory = makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        let store = NoteStore(sessionDirectory: directory, observesTermination: false)
        store.ensureReady()
        let note = store.createNote()
        store.updateContent("hello", for: note.id)
        store.setLineNumbersVisible(true)
        store.saveNow()

        let restored = NoteStore(sessionDirectory: directory, observesTermination: false)
        restored.ensureReady()

        try expect(restored.notes.count == 2, "expected restored notes")
        try expect(restored.selectedNote?.id == note.id, "expected selected note to restore")
        try expect(restored.selectedNote?.content == "hello", "expected note content to restore")
        try expect(restored.settings.showLineNumbers, "expected line-number setting to restore")
    }

    @MainActor
    private static func sessionRestoreDropsDuplicateNoteIDs() throws {
        let directory = makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let duplicateID = UUID()
        let first = Note(id: duplicateID, content: "first")
        let second = Note(id: duplicateID, content: "second")
        let state = SessionState(notes: [first, second], selectedNoteID: duplicateID, settings: EditorSettings())
        let data = try JSONEncoder.testSessionEncoder.encode(state)
        try data.write(to: directory.appendingPathComponent("session.json"))

        let restored = NoteStore(sessionDirectory: directory, observesTermination: false)
        restored.ensureReady()

        try expect(restored.notes.count == 1, "expected duplicate note ids to be dropped")
        try expect(restored.selectedNote?.content == "first", "expected first duplicate to win")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() {
            throw TestFailure(message)
        }
    }

    private static func makeTemporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("myPadTests-\(UUID().uuidString)", isDirectory: true)
    }

    private static func removeTemporaryDirectory(_ directory: URL) {
        try? FileManager.default.removeItem(at: directory)
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

private extension JSONEncoder {
    static var testSessionEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
