import SwiftUI

struct ContentView: View {
    @ObservedObject var store: NoteStore
    let noteID: UUID

    var body: some View {
        VStack(spacing: 0) {
            EditorToolbarView(store: store)

            Divider()

            if let text = store.textBinding(for: noteID) {
                PlainTextEditor(
                    text: text,
                    settings: store.settings,
                    onOptionScrollZoom: store.zoomFromScroll
                )
                    .id(noteID)
            } else {
                ContentUnavailableView("No Note", systemImage: "note.text")
            }

            Divider()

            StatusBarView(store: store, noteID: noteID)
        }
    }
}
