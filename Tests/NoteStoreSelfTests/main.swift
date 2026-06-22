import Foundation

@main
struct NoteStoreSelfTests {
    @MainActor
    static func main() throws {
        try createNoteSelectsNewTab()
        try closeSelectedNoteRemovesTabAndSelectsNeighbor()
        try sessionRestorePreservesSelectedNoteAndSettings()
        try sessionRestoreDropsDuplicateNoteIDs()
        try customTitleOverridesGeneratedTitle()
        try openFileCreatesFileBackedTab()
        try sessionExportImportAppendsNotes()
        try noteStatsCountWordsAndReadTime()
        try tableFormatterCreatesSkeleton()
        try tableFormatterConvertsDelimitedText()
        try tableFormatterFormatsCurrentTable()
        try tableFormatterNarrowsSelectionToTableBlock()
        try tableFormatterIgnoresFencedCodeTables()
        try markdownPreviewParserFindsExpectedBlocks()
        try markdownPreviewParserPreservesNestedListMetadata()
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

    @MainActor
    private static func customTitleOverridesGeneratedTitle() throws {
        var note = Note(content: "# Generated", customTitle: "Pinned Name")

        try expect(note.title == "Pinned Name", "expected custom title to win")

        note.customTitle = nil
        try expect(note.title == "# Generated", "expected generated title after clearing custom title")
    }

    @MainActor
    private static func openFileCreatesFileBackedTab() throws {
        let directory = makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("opened.md")
        try "# Opened\nBody".write(to: fileURL, atomically: true, encoding: .utf8)
        let sessionDirectory = directory.appendingPathComponent("session", isDirectory: true)
        let store = NoteStore(sessionDirectory: sessionDirectory, observesTermination: false)
        store.ensureReady()

        let note = store.openFileURL(fileURL)

        try expect(note?.content == "# Opened\nBody", "expected opened file content")
        try expect(note?.filePath == fileURL.path, "expected opened note to keep file path")
        try expect(store.selectedNote?.id == note?.id, "expected opened file to be selected")
    }

    @MainActor
    private static func sessionExportImportAppendsNotes() throws {
        let directory = makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        let exportURL = directory.appendingPathComponent("session.json")
        let source = NoteStore(sessionDirectory: directory.appendingPathComponent("source", isDirectory: true), observesTermination: false)
        source.ensureReady()
        let exported = source.createNote()
        source.updateContent("exported", for: exported.id)
        source.exportSession(to: exportURL)
        let exportedState = try JSONDecoder.testSessionDecoder.decode(SessionState.self, from: Data(contentsOf: exportURL))
        try expect(exportedState.notes.contains { $0.content == "exported" }, "expected exported note")

        let destination = NoteStore(sessionDirectory: directory.appendingPathComponent("destination", isDirectory: true), observesTermination: false)
        destination.ensureReady()
        destination.importSession(from: exportURL)

        try expect(destination.notes.contains { $0.content == "exported" }, "expected imported note")
        try expect(destination.notes.count == 3, "expected import to append session notes")
    }

    private static func noteStatsCountWordsAndReadTime() throws {
        let note = Note(content: "one two\nthree")

        try expect(note.wordCount == 3, "expected words to be counted")
        try expect(note.estimatedReadMinutes == 1, "expected non-empty notes to have at least one read minute")
    }

    private static func tableFormatterCreatesSkeleton() throws {
        let table = MarkdownTableFormatter.makeTable(rows: 3, columns: 3)
        let lines = table.components(separatedBy: "\n")

        try expect(lines.count == 4, "expected header, separator, and body rows")
        try expect(lines[0] == "| Column 1 | Column 2 | Column 3 |", "expected generated table headers")
        try expect(lines[1] == "| -------- | -------- | -------- |", "expected generated separator row")
    }

    private static func tableFormatterConvertsDelimitedText() throws {
        let table = MarkdownTableFormatter.convertDelimitedTextToTable("Name,Score\nAda,10\nLinus,9")

        try expect(
            table == """
            | Name  | Score |
            | ----- | ----- |
            | Ada   | 10    |
            | Linus | 9     |
            """,
            "expected CSV text to become a padded markdown table"
        )
    }

    private static func tableFormatterFormatsCurrentTable() throws {
        let table = MarkdownTableFormatter.formatTableBlock("| A|Long |\n|---|---:|\n| x | 20|")

        try expect(
            table == """
            | A   | Long |
            | --- | ---: |
            | x   | 20   |
            """,
            "expected ragged markdown table to be aligned"
        )
    }

    private static func tableFormatterNarrowsSelectionToTableBlock() throws {
        let document = """
        Intro
        | A | B |
        | --- | --- |
        | 1 | 2 |
        Outro
        """
        let fullRange = NSRange(location: 0, length: (document as NSString).length)
        let result = MarkdownTableFormatter.formatTable(in: document, selectedRange: fullRange)

        try expect(result?.range == (document as NSString).range(of: "| A | B |\n| --- | --- |\n| 1 | 2 |"), "expected only the table block to be replaced")
    }

    private static func tableFormatterIgnoresFencedCodeTables() throws {
        let document = """
        ```
        | A | B |
        | --- | --- |
        ```
        """
        let range = (document as NSString).range(of: "| A | B |")

        try expect(
            MarkdownTableFormatter.formatTable(in: document, selectedRange: range) == nil,
            "expected tables inside fenced code blocks to be ignored"
        )
    }

    private static func markdownPreviewParserFindsExpectedBlocks() throws {
        let blocks = MarkdownPreviewParser.parse(
            """
            # Title

            - [x] Done

            | A | B |
            | --- | ---: |
            | 1 | 2 |

            ![Diagram](diagram.png)
            """
        )

        guard blocks.count == 4 else {
            throw TestFailure("expected heading, task list, table, and image blocks")
        }

        guard case .heading(let level, let title) = blocks[0] else {
            throw TestFailure("expected first block to be a heading")
        }

        try expect(level == 1 && title == "Title", "expected heading metadata")

        guard case .unorderedList(let items) = blocks[1] else {
            throw TestFailure("expected second block to be a task list")
        }

        try expect(items.first?.text == "Done", "expected task item text")

        guard case .table(let table) = blocks[2] else {
            throw TestFailure("expected third block to be a table")
        }

        try expect(table.headers == ["A", "B"], "expected table headers")
        try expect(table.rows == [["1", "2"]], "expected table rows")

        guard case .image(let altText, let source) = blocks[3] else {
            throw TestFailure("expected fourth block to be an image")
        }

        try expect(altText == "Diagram" && source == "diagram.png", "expected image metadata")
    }

    private static func markdownPreviewParserPreservesNestedListMetadata() throws {
        let blocks = MarkdownPreviewParser.parse(
            """
            • Parent
               • Child
                  • Grandchild

            1. One
            2. Two
               2.1. Two One
                  2.1.1. Two One One
            3. Three

            [x] Done
               [ ] Later
            """
        )

        guard blocks.count == 3 else {
            throw TestFailure("expected bullet, ordered, and task list blocks")
        }

        guard case .unorderedList(let bullets) = blocks[0] else {
            throw TestFailure("expected first block to be bullet list")
        }

        try expect(bullets.map(\.depth) == [0, 1, 2], "expected bullet indentation depth")

        guard case .orderedList(let ordered) = blocks[1] else {
            throw TestFailure("expected second block to be ordered list")
        }

        let orderedMarkers = ordered.map { item -> String in
            if case .ordered(let marker) = item.marker {
                return marker
            }

            return ""
        }
        try expect(orderedMarkers == ["1.", "2.", "2.1.", "2.1.1.", "3."], "expected ordered markers to be preserved")
        try expect(ordered.map(\.depth) == [0, 0, 1, 2, 0], "expected ordered indentation depth")

        guard case .unorderedList(let tasks) = blocks[2] else {
            throw TestFailure("expected third block to be task list")
        }

        try expect(tasks.map(\.depth) == [0, 1], "expected task indentation depth")
        try expect(tasks.compactMap(\.taskState).count == 2, "expected task states")
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

private extension JSONDecoder {
    static var testSessionDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
