import AppKit
import SwiftUI

struct NoteWindowView: View {
    @ObservedObject var store: NoteStore
    @State private var noteID: UUID?
    @Environment(\.openWindow) private var openWindow

    private var resolvedNoteID: UUID? {
        if let noteID, store.note(withID: noteID) != nil {
            return noteID
        }

        return nil
    }

    private var resolvedNote: Note? {
        guard let resolvedNoteID else {
            return nil
        }

        return store.note(withID: resolvedNoteID)
    }

    var body: some View {
        Group {
            if let resolvedNoteID {
                ContentView(store: store, noteID: resolvedNoteID)
                    .focusedValue(
                        \.noteCommandTarget,
                        NoteCommandTarget(store: store, noteID: resolvedNoteID)
                    )
                    .background(
                        NativeTabWindowConfiguration(
                            title: resolvedNote?.title ?? "myPad",
                            onBecameKey: {
                                store.select(noteID: resolvedNoteID)
                            },
                            onWillClose: {
                                store.unregisterWindow(noteID: resolvedNoteID)
                            }
                        )
                    )
                    .onAppear {
                        store.select(noteID: resolvedNoteID)
                    }
            } else {
                ContentUnavailableView("No Note", systemImage: "note.text")
            }
        }
        .onAppear {
            store.ensureReady()
            resolveWindowNote()
            scheduleNativeNoteWindowRestore()
        }
        .onChange(of: store.notes.map(\.id)) { _, _ in
            resolveWindowNote()
        }
        .onChange(of: noteID) { _, _ in
            resolveWindowNote()
        }
    }

    private func resolveWindowNote() {
        if let noteID, store.note(withID: noteID) != nil {
            let registeredNoteID = store.registerWindow(noteID: noteID)
            store.select(noteID: registeredNoteID)
            return
        }

        let nextNoteID = store.noteIDForUntitledWindow()
        noteID = nextNoteID
        store.select(noteID: nextNoteID)
    }

    private func scheduleNativeNoteWindowRestore() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for _ in store.noteIDsForRestoredWindows() {
                openWindow(id: "note")
            }
        }
    }
}
