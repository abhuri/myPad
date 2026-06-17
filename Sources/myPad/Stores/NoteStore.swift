import AppKit
import Foundation
import SwiftUI

@MainActor
final class NoteStore: ObservableObject {
    @Published private(set) var notes: [Note] = []
    @Published var selectedNoteID: UUID?
    @Published private(set) var settings = EditorSettings()
    @Published private(set) var saveState = "Saved"

    private let customSessionDirectory: URL?
    private var didLoad = false
    private var saveWorkItem: DispatchWorkItem?
    private var terminationObserver: NSObjectProtocol?

    init(sessionDirectory: URL? = nil, observesTermination: Bool = true) {
        customSessionDirectory = sessionDirectory

        if observesTermination {
            terminationObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.willTerminateNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.saveNow()
                }
            }
        }
    }

    deinit {
        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
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

    func createNote() {
        let note = Note()
        notes.append(note)
        selectedNoteID = note.id
        saveSoon()
    }

    func select(noteID: UUID) {
        selectedNoteID = noteID
        saveSoon()
    }

    func closeSelectedNote() {
        guard let index = selectedNoteIndex else {
            createNote()
            return
        }

        if notes.count == 1 {
            notes = [Note()]
            selectedNoteID = notes[0].id
            saveSoon()
            return
        }

        notes.remove(at: index)
        let nextIndex = min(index, notes.count - 1)
        selectedNoteID = notes[nextIndex].id
        saveSoon()
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

    func selectedTextBinding() -> Binding<String>? {
        guard let noteID = selectedNote?.id else {
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
