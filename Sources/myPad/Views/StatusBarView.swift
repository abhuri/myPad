import SwiftUI

struct StatusBarView: View {
    @ObservedObject var store: NoteStore
    let noteID: UUID

    var body: some View {
        HStack(spacing: 12) {
            if let note = store.note(withID: noteID) {
                Text("\(note.characterCount) characters")
                Text("\(note.lineCount) lines")
            }

            Text("\(store.notes.count) notes")

            Spacer()

            Toggle(isOn: themeToggle) {
                Image(systemName: store.settings.theme == .dark ? "moon.fill" : "sun.max.fill")
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .help(store.settings.theme == .dark ? "Switch to Light Theme" : "Switch to Dark Theme")

            Text(store.saveState)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.bar)
    }

    private var themeToggle: Binding<Bool> {
        Binding(
            get: { store.settings.theme == .dark },
            set: { store.setTheme($0 ? .dark : .light) }
        )
    }
}
