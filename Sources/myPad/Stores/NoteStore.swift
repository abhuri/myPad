import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class NoteStore: ObservableObject {
    @Published private(set) var notes: [Note] = []
    @Published var selectedNoteID: UUID?
    @Published private(set) var settings = EditorSettings()
    @Published private(set) var saveState = "Saved"

    private let customSessionDirectory: URL?
    private var didLoad = false
    private var didAssignInitialWindow = false
    private var windowNoteIDs = Set<UUID>()
    private var pendingWindowNoteIDs = Set<UUID>()
    private var pendingWindowNoteQueue: [UUID] = []
    private var isTerminating = false
    private var saveWorkItem: DispatchWorkItem?
    private var terminationObserver: NSObjectProtocol?
    private var quitObserver: NSObjectProtocol?

    init(sessionDirectory: URL? = nil, observesTermination: Bool = true) {
        customSessionDirectory = sessionDirectory

        if observesTermination {
            quitObserver = NotificationCenter.default.addObserver(
                forName: .myPadWillQuit,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.prepareForQuit()
                }
            }

            terminationObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.willTerminateNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.prepareForQuit()
                }
            }
        }
    }

    deinit {
        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
        }

        if let quitObserver {
            NotificationCenter.default.removeObserver(quitObserver)
        }
    }

    var selectedNote: Note? {
        guard let selectedNoteID else {
            return notes.first
        }

        return notes.first { $0.id == selectedNoteID }
    }

    var selectedNoteIndex: Int? {
        guard let selectedNoteID else {
            return notes.indices.first
        }

        return notes.firstIndex { $0.id == selectedNoteID }
    }

    func ensureReady() {
        guard !didLoad else {
            return
        }

        didLoad = true
        loadSession()
    }

    @discardableResult
    func createNote() -> Note {
        let note = Note()
        notes.append(note)
        selectedNoteID = note.id
        saveSoon()
        return note
    }

    func select(noteID: UUID) {
        selectedNoteID = noteID
        saveSoon()
    }

    func noteIDForUntitledWindow() -> UUID {
        if let pendingNoteID = dequeuePendingWindowNoteID() {
            selectedNoteID = pendingNoteID
            return registerWindow(noteID: pendingNoteID)
        }

        if !didAssignInitialWindow {
            didAssignInitialWindow = true

            if let selectedNote {
                return registerWindow(noteID: selectedNote.id)
            }

            if let firstNote = notes.first {
                selectedNoteID = firstNote.id
                return registerWindow(noteID: firstNote.id)
            }

            return registerWindow(noteID: createNote().id)
        }

        if let unassignedNote = notes.first(where: { note in
            !windowNoteIDs.contains(note.id) && !pendingWindowNoteIDs.contains(note.id)
        }) {
            selectedNoteID = unassignedNote.id
            return registerWindow(noteID: unassignedNote.id)
        }

        return registerWindow(noteID: createNote().id)
    }

    @discardableResult
    func registerWindow(noteID: UUID) -> UUID {
        pendingWindowNoteIDs.remove(noteID)
        pendingWindowNoteQueue.removeAll { $0 == noteID }
        windowNoteIDs.insert(noteID)
        return noteID
    }

    func noteIDsForRestoredWindows() -> [UUID] {
        let noteIDs = notes
            .map(\.id)
            .filter { !windowNoteIDs.contains($0) && !pendingWindowNoteIDs.contains($0) }

        pendingWindowNoteIDs.formUnion(noteIDs)
        pendingWindowNoteQueue.append(contentsOf: noteIDs)
        return noteIDs
    }

    func closeSelectedNote() {
        guard let noteID = selectedNote?.id else {
            createNote()
            return
        }

        closeNoteWindow(noteID: noteID)
    }

    func closeNoteWindow(noteID: UUID) {
        unregisterWindow(noteID: noteID)

        guard !isTerminating else {
            return
        }

        guard let index = noteIndex(for: noteID) else {
            return
        }

        if notes.count == 1 {
            saveNow()
            NSApp.terminate(nil)
            return
        }

        notes.remove(at: index)
        let nextIndex = min(index, notes.count - 1)
        selectedNoteID = notes[nextIndex].id
        saveSoon()
    }

    func unregisterWindow(noteID: UUID) {
        windowNoteIDs.remove(noteID)
        pendingWindowNoteIDs.remove(noteID)
        pendingWindowNoteQueue.removeAll { $0 == noteID }
    }

    func prepareForQuit() {
        isTerminating = true
        saveNow()
    }

    private func dequeuePendingWindowNoteID() -> UUID? {
        while !pendingWindowNoteQueue.isEmpty {
            let noteID = pendingWindowNoteQueue.removeFirst()
            pendingWindowNoteIDs.remove(noteID)

            if note(withID: noteID) != nil, !windowNoteIDs.contains(noteID) {
                return noteID
            }
        }

        return nil
    }

    func updateContent(_ content: String, for noteID: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else {
            return
        }

        guard notes[index].content != content else {
            return
        }

        notes[index].content = content
        notes[index].updatedAt = Date()
        saveSoon()
    }

    func note(withID noteID: UUID) -> Note? {
        notes.first { $0.id == noteID }
    }

    func noteIndex(for noteID: UUID) -> Int? {
        notes.firstIndex { $0.id == noteID }
    }

    func textBinding(for noteID: UUID) -> Binding<String>? {
        guard notes.contains(where: { $0.id == noteID }) else {
            return nil
        }

        return Binding(
            get: { [weak self] in
                self?.notes.first { $0.id == noteID }?.content ?? ""
            },
            set: { [weak self] newContent in
                self?.updateContent(newContent, for: noteID)
            }
        )
    }

    func selectedTextBinding() -> Binding<String>? {
        guard let noteID = selectedNote?.id else {
            return nil
        }

        return textBinding(for: noteID)
    }

    func setFontName(_ fontName: String) {
        settings.fontName = fontName
        saveSoon()
    }

    func setFontSize(_ fontSize: Double) {
        settings.fontSize = max(9, min(72, fontSize))
        saveSoon()
    }

    func setWordWrap(_ enabled: Bool) {
        settings.wordWrap = enabled
        saveSoon()
    }

    func setLineNumbersVisible(_ visible: Bool) {
        settings.showLineNumbers = visible
        saveSoon()
    }

    func setTheme(_ theme: EditorTheme) {
        settings.theme = theme
        saveSoon()
    }

    func toggleTheme() {
        setTheme(settings.theme == .dark ? .light : .dark)
    }

    func toggleBoldMarkdown() {
        postEditorCommand(.boldMarkdown)
    }

    func toggleItalicMarkdown() {
        postEditorCommand(.italicMarkdown)
    }

    func applyListStyle(_ style: EditorListStyle) {
        postEditorCommand(.list(style))
    }

    func saveSelectedNote() {
        guard let noteID = selectedNote?.id else {
            return
        }

        saveNote(noteID)
    }

    func saveNote(_ noteID: UUID) {
        guard let note = note(withID: noteID) else {
            return
        }

        guard let filePath = note.filePath, !filePath.isEmpty else {
            saveNoteAs(noteID)
            return
        }

        writeNote(noteID, to: URL(fileURLWithPath: filePath))
    }

    func saveSelectedNoteAs() {
        guard let noteID = selectedNote?.id else {
            return
        }

        saveNoteAs(noteID)
    }

    func saveNoteAs(_ noteID: UUID) {
        guard let note = note(withID: noteID) else {
            return
        }

        let panel = NSSavePanel()
        let defaultFormat = NoteSaveFormat.format(for: note.filePath) ?? .plainText
        let formatPicker = NSPopUpButton(frame: .zero, pullsDown: false)
        let formatSelectionTarget = SaveFormatSelectionTarget(panel: panel)

        for format in NoteSaveFormat.allCases {
            formatPicker.addItem(withTitle: format.menuTitle)
        }

        formatPicker.selectItem(at: NoteSaveFormat.allCases.firstIndex(of: defaultFormat) ?? 0)
        formatPicker.target = formatSelectionTarget
        formatPicker.action = #selector(SaveFormatSelectionTarget.formatChanged(_:))

        let accessory = NSStackView()
        accessory.orientation = .horizontal
        accessory.alignment = .centerY
        accessory.spacing = 8
        accessory.addArrangedSubview(NSTextField(labelWithString: "Format:"))
        accessory.addArrangedSubview(formatPicker)

        panel.title = "Save Note"
        panel.nameFieldStringValue = suggestedFileName(for: note, format: defaultFormat)
        panel.allowedContentTypes = NoteSaveFormat.allCases.map(\.contentType)
        panel.allowsOtherFileTypes = false
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.accessoryView = accessory

        let response = withExtendedLifetime(formatSelectionTarget) {
            panel.runModal()
        }

        guard response == .OK, let selectedURL = panel.url else {
            return
        }

        let selectedFormat = NoteSaveFormat.allCases[
            max(0, min(formatPicker.indexOfSelectedItem, NoteSaveFormat.allCases.count - 1))
        ]
        writeNote(noteID, to: url(selectedURL, matching: selectedFormat))
    }

    func zoomIn() {
        settings.zoom = min(3, (settings.zoom + 0.1).rounded(toPlaces: 2))
        saveSoon()
    }

    func zoomOut() {
        settings.zoom = max(0.5, (settings.zoom - 0.1).rounded(toPlaces: 2))
        saveSoon()
    }

    func resetZoom() {
        settings.zoom = 1
        saveSoon()
    }

    func zoomFromScroll(_ delta: CGFloat) {
        if delta > 0 {
            zoomIn()
        } else if delta < 0 {
            zoomOut()
        }
    }

    private func postEditorCommand(_ command: EditorCommand) {
        NotificationCenter.default.post(name: .myPadEditorCommand, object: command)
    }

    private func writeNote(_ noteID: UUID, to url: URL) {
        guard let index = noteIndex(for: noteID) else {
            return
        }

        do {
            try notes[index].content.write(to: url, atomically: true, encoding: .utf8)
            notes[index].filePath = url.path
            notes[index].updatedAt = Date()
            saveNow()
            saveState = "Saved to file"
        } catch {
            saveState = "File save failed"
        }
    }

    private func suggestedFileName(for note: Note, format: NoteSaveFormat) -> String {
        let baseName = sanitizedFileName(from: note.title)
        return "\(baseName).\(format.fileExtension)"
    }

    private func sanitizedFileName(from title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty || trimmed == "Untitled" ? "Untitled Note" : trimmed
        let invalidCharacters = CharacterSet(charactersIn: "/:")
            .union(.newlines)
            .union(.controlCharacters)
        let pieces = fallback.components(separatedBy: invalidCharacters)
        let sanitized = pieces
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? "Untitled Note" : sanitized
    }

    private func url(_ url: URL, matching format: NoteSaveFormat) -> URL {
        url.deletingPathExtension().appendingPathExtension(format.fileExtension)
    }

    func saveSoon() {
        saveState = "Saving..."
        saveWorkItem?.cancel()

        let item = DispatchWorkItem { [weak self] in
            self?.saveNow()
        }

        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: item)
    }

    func saveNow() {
        saveWorkItem?.cancel()
        saveWorkItem = nil

        do {
            let directory = try sessionDirectory()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let state = SessionState(notes: notes, selectedNoteID: selectedNoteID, settings: settings)
            let data = try JSONEncoder.sessionEncoder.encode(state)
            try data.write(to: sessionFileURL(in: directory), options: [.atomic])
            saveState = "Saved"
        } catch {
            saveState = "Save failed"
        }
    }

    private func loadSession() {
        do {
            let directory = try sessionDirectory()
            let url = sessionFileURL(in: directory)

            if FileManager.default.fileExists(atPath: url.path) {
                let data = try Data(contentsOf: url)
                let state = try JSONDecoder.sessionDecoder.decode(SessionState.self, from: data)
                notes = state.notes.isEmpty ? [Note()] : state.notes
                settings = state.settings
                selectedNoteID = state.selectedNoteID

                if selectedNoteID == nil || !notes.contains(where: { $0.id == selectedNoteID }) {
                    selectedNoteID = notes.first?.id
                }

                saveState = "Saved"
                return
            }
        } catch {
            saveState = "Save failed"
        }

        notes = [Note()]
        selectedNoteID = notes.first?.id
        saveSoon()
    }

    private func sessionDirectory() throws -> URL {
        if let customSessionDirectory {
            return customSessionDirectory
        }

        return try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("myPad", isDirectory: true)
    }

    private func sessionFileURL(in directory: URL) -> URL {
        directory.appendingPathComponent("session.json")
    }
}

private extension JSONEncoder {
    static var sessionEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var sessionDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

private enum NoteSaveFormat: CaseIterable, Equatable {
    case plainText
    case markdown

    var menuTitle: String {
        switch self {
        case .plainText:
            return "Plain Text (.txt)"
        case .markdown:
            return "Markdown (.md)"
        }
    }

    var fileExtension: String {
        switch self {
        case .plainText:
            return "txt"
        case .markdown:
            return "md"
        }
    }

    var contentType: UTType {
        switch self {
        case .plainText:
            return .plainText
        case .markdown:
            return UTType(filenameExtension: "md") ?? .plainText
        }
    }

    static func format(for filePath: String?) -> NoteSaveFormat? {
        guard let filePath else {
            return nil
        }

        switch URL(fileURLWithPath: filePath).pathExtension.lowercased() {
        case "txt":
            return .plainText
        case "md", "markdown":
            return .markdown
        default:
            return nil
        }
    }
}

private final class SaveFormatSelectionTarget: NSObject {
    weak var panel: NSSavePanel?

    init(panel: NSSavePanel) {
        self.panel = panel
    }

    @objc func formatChanged(_ sender: NSPopUpButton) {
        guard let panel else {
            return
        }

        let selectedFormat = NoteSaveFormat.allCases[
            max(0, min(sender.indexOfSelectedItem, NoteSaveFormat.allCases.count - 1))
        ]
        let baseName = URL(fileURLWithPath: panel.nameFieldStringValue)
            .deletingPathExtension()
            .lastPathComponent
        panel.nameFieldStringValue = "\(baseName).\(selectedFormat.fileExtension)"
    }
}
