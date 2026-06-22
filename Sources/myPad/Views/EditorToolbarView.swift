import SwiftUI

struct EditorToolbarView: View {
    @ObservedObject var store: NoteStore

    var body: some View {
        HStack(spacing: 8) {
            Picker("View Mode", selection: viewModeSelection) {
                ForEach(EditorViewMode.allCases) { mode in
                    Image(systemName: mode.systemImageName)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 104)
            .help("View Mode")

            Divider()
                .frame(height: 18)

            Button {
                store.toggleBoldMarkdown()
            } label: {
                Image(systemName: "bold")
            }
            .help("Bold")
            .disabled(!isEditingEnabled)

            Button {
                store.toggleItalicMarkdown()
            } label: {
                Image(systemName: "italic")
            }
            .help("Italic")
            .disabled(!isEditingEnabled)

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
            .disabled(!isEditingEnabled)

            Menu {
                Button("Insert 2 x 2 Table") {
                    store.insertTable(rows: 2, columns: 2)
                }

                Button("Insert 3 x 3 Table") {
                    store.insertTable(rows: 3, columns: 3)
                }

                Button("Insert 4 x 4 Table") {
                    store.insertTable(rows: 4, columns: 4)
                }

                Divider()

                Button("Format Table") {
                    store.formatTable()
                }

                Button("Convert Selection to Table") {
                    store.convertSelectionToTable()
                }
            } label: {
                Label("Tables", systemImage: "tablecells")
                    .labelStyle(.iconOnly)
            }
            .help("Tables")
            .disabled(!isEditingEnabled)

            Spacer()
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private var viewModeSelection: Binding<EditorViewMode> {
        Binding(
            get: { store.settings.viewMode },
            set: { store.setViewMode($0) }
        )
    }

    private var isEditingEnabled: Bool {
        store.settings.viewMode != .preview
    }
}
