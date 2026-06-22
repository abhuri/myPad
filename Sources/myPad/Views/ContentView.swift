import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var store: NoteStore
    @State private var isFileDropTargeted = false
    @State private var scrollProgress = 0.0
    @State private var scrollSource: EditorScrollSyncSource = .editor

    var body: some View {
        VStack(spacing: 0) {
            TabBarView(store: store)

            Divider()

            EditorToolbarView(store: store)

            if store.isFindReplaceVisible {
                Divider()
                FindReplaceBarView(store: store)
            }

            Divider()

            if let text = store.selectedTextBinding() {
                editorContent(for: text)
            } else {
                ContentUnavailableView("No Note", systemImage: "note.text")
            }

            Divider()

            StatusBarView(store: store)
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isFileDropTargeted, perform: openDroppedFiles)
        .overlay {
            if isFileDropTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
        .background(MacWindowTabBarSuppressor())
    }

    @ViewBuilder
    private func editorContent(for text: Binding<String>) -> some View {
        switch store.settings.viewMode {
        case .edit:
            editor(for: text)
        case .split:
            HSplitView {
                editor(for: text)
                    .frame(minWidth: 260)

                markdownPreview(for: text.wrappedValue)
                    .frame(minWidth: 260)
            }
        case .preview:
            markdownPreview(for: text.wrappedValue)
        }
    }

    private func editor(for text: Binding<String>) -> some View {
        PlainTextEditor(
            text: text,
            settings: store.settings,
            onOptionScrollZoom: store.zoomFromScroll,
            scrollProgress: scrollProgress,
            scrollSource: scrollSource,
            onScrollProgressChange: { progress in
                scrollSource = .editor
                scrollProgress = progress
            },
            onOpenFileURLs: store.openFileURLs
        )
        .id(store.selectedNote?.id)
    }

    private func markdownPreview(for text: String) -> some View {
        MarkdownPreviewView(
            text: text,
            settings: store.settings,
            baseURL: selectedNoteBaseURL,
            scrollProgress: scrollProgress,
            scrollSource: scrollSource,
            onScrollProgressChange: { progress in
                scrollSource = .preview
                scrollProgress = progress
            }
        )
    }

    private var selectedNoteBaseURL: URL? {
        guard let filePath = store.selectedNote?.filePath, !filePath.isEmpty else {
            return nil
        }

        return URL(fileURLWithPath: filePath).deletingLastPathComponent()
    }

    private func openDroppedFiles(_ providers: [NSItemProvider]) -> Bool {
        var didLoadFile = false

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            didLoadFile = true
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url = fileURL(from: item)

                if let url {
                    DispatchQueue.main.async {
                        store.openFileURLs([url])
                    }
                }
            }
        }

        return didLoadFile
    }

    private func fileURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }

        if let data = item as? Data,
           let string = String(data: data, encoding: .utf8) {
            return URL(string: string)
        }

        if let string = item as? String {
            return URL(string: string)
        }

        return nil
    }
}
