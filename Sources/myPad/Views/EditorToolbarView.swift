import SwiftUI

struct EditorToolbarView: View {
    @ObservedObject var store: NoteStore

    var body: some View {
        HStack(spacing: 8) {
            Button {
                store.toggleBoldMarkdown()
            } label: {
                Image(systemName: "bold")
            }
            .help("Bold")

            Button {
                store.toggleItalicMarkdown()
            } label: {
                Image(systemName: "italic")
            }
            .help("Italic")

            Menu {
                Button("Bullet List") {
                    store.applyListStyle(.bullet)
                }

                Button("Numbered List") {
                    store.applyListStyle(.numbered)
                }

                Button("Checkbox List") {
                    store.applyListStyle(.checkbox)
                }
            } label: {
                Label("Lists", systemImage: "list.bullet")
                    .labelStyle(.iconOnly)
            }
            .help("Lists")

            Spacer()
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
