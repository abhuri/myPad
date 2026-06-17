import SwiftUI

struct StatusBarView: View {
    @ObservedObject var store: NoteStore

    var body: some View {
        HStack(spacing: 12) {
            if let note = store.selectedNote {
                Text("\(note.characterCount) characters")
                Text("\(note.lineCount) lines")
            }

            Text("\(store.notes.count) tabs")

            Spacer()

            Text(store.saveState)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.bar)
    }
}
