import SwiftUI

struct EditorToolbarView: View {
    @ObservedObject var store: NoteStore

    var body: some View {
        HStack(spacing: 10) {
            Picker("Font", selection: fontSelection) {
                ForEach(EditorSettings.availableFontNames, id: \.self) { fontName in
                    Text(fontName).tag(fontName)
                }
            }
            .labelsHidden()
            .frame(width: 180)

            Stepper(value: fontSize, in: 9...72, step: 1) {
                Text("\(Int(store.settings.fontSize)) pt")
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)
            }
            .frame(width: 118)

            Divider()
                .frame(height: 18)

            Toggle(isOn: wordWrap) {
                Text("Wrap")
            }
            .toggleStyle(.checkbox)

            Divider()
                .frame(height: 18)

            Button {
                store.zoomOut()
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .help("Zoom Out")

            Text("\(Int(store.settings.zoom * 100))%")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 42)

            Button {
                store.zoomIn()
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .help("Zoom In")

            Button {
                store.resetZoom()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .help("Reset Zoom")

            Spacer()
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private var fontSelection: Binding<String> {
        Binding(
            get: { store.settings.fontName },
            set: { store.setFontName($0) }
        )
    }

    private var fontSize: Binding<Double> {
        Binding(
            get: { store.settings.fontSize },
            set: { store.setFontSize($0) }
        )
    }

    private var wordWrap: Binding<Bool> {
        Binding(
            get: { store.settings.wordWrap },
            set: { store.setWordWrap($0) }
        )
    }
}
