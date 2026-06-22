import SwiftUI

struct FindReplaceBarView: View {
    @ObservedObject var store: NoteStore

    var body: some View {
        HStack(spacing: 8) {
            TextField("Find", text: $store.findQuery)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 160)
                .onSubmit {
                    store.findNext()
                }

            TextField("Replace", text: $store.replacementText)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 160)
                .onSubmit {
                    store.replaceNext()
                }

            Button {
                store.findNext()
            } label: {
                Image(systemName: "chevron.down")
            }
            .help("Find Next")
            .disabled(!isEditingEnabled)

            Button {
                store.replaceNext()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
            }
            .help("Replace Next")
            .disabled(!isEditingEnabled)

            Button {
                store.replaceAll()
            } label: {
                Image(systemName: "text.badge.checkmark")
            }
            .help("Replace All")
            .disabled(!isEditingEnabled)

            Spacer()

            Button {
                store.hideFindReplace()
            } label: {
                Image(systemName: "xmark")
            }
            .help("Close Find and Replace")
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private var isEditingEnabled: Bool {
        store.settings.viewMode != .preview
    }
}
