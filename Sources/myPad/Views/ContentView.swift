import SwiftUI

struct ContentView: View {
    @ObservedObject var store: NoteStore

    var body: some View {
        VStack(spacing: 0) {
            TabBarView(store: store)

            Divider()

            EditorToolbarView(store: store)

            Divider()

            if let text = store.selectedTextBinding() {
                PlainTextEditor(text: text, settings: store.settings)
                    .id(store.selectedNote?.id)
            } else {
                ContentUnavailableView("No Note", systemImage: "note.text")
            }

            Divider()

            StatusBarView(store: store)
        }
    }
}
