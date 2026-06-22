import AppKit
import SwiftUI

@main
struct MyPadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = NoteStore()

    var body: some Scene {
        Window("myPad", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 720, minHeight: 460)
                .preferredColorScheme(store.settings.theme.colorScheme)
                .onAppear {
                    store.ensureReady()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    store.saveNow()
                }
                .onReceive(NotificationCenter.default.publisher(for: .myPadOpenFileURLs)) { notification in
                    guard let urls = notification.object as? [URL] else {
                        return
                    }

                    store.openFileURLs(urls)
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Tab") {
                    store.createNote()
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Open...") {
                    store.openNote()
                }
                .keyboardShortcut("o", modifiers: [.command])
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    store.saveSelectedNote()
                }
                .keyboardShortcut("s", modifiers: [.command])

                Button("Save As...") {
                    store.saveSelectedNoteAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }

            CommandGroup(after: .saveItem) {
                Divider()

                Button("Import Session...") {
                    store.importSession()
                }

                Button("Export Session...") {
                    store.exportSession()
                }
            }

            CommandMenu("Note") {
                Button("Close Tab") {
                    store.closeSelectedNote()
                }
                .keyboardShortcut("w", modifiers: [.command])

                Button("Rename Tab...") {
                    store.renameSelectedNote()
                }
                .keyboardShortcut("r", modifiers: [.command, .option])

                Divider()

                Button(store.settings.wordWrap ? "Turn Word Wrap Off" : "Turn Word Wrap On") {
                    store.setWordWrap(!store.settings.wordWrap)
                }
                .keyboardShortcut("w", modifiers: [.command, .option])

                Toggle("Show Line Numbers", isOn: lineNumbersSelection)
                    .keyboardShortcut("l", modifiers: [.command, .option])

                Divider()

                Button("Editor Only") {
                    store.setViewMode(.edit)
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button("Split Editor and Preview") {
                    store.setViewMode(.split)
                }
                .keyboardShortcut("2", modifiers: [.command])

                Button("Preview Only") {
                    store.setViewMode(.preview)
                }
                .keyboardShortcut("3", modifiers: [.command])
            }

            CommandMenu("Search") {
                Button("Find and Replace...") {
                    store.showFindReplace()
                }
                .keyboardShortcut("f", modifiers: [.command, .option])
                .disabled(store.settings.viewMode == .preview)

                Button("Find Next") {
                    store.findNext()
                }
                .keyboardShortcut("g", modifiers: [.command])
                .disabled(store.settings.viewMode == .preview)

                Button("Replace Next") {
                    store.replaceNext()
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(store.settings.viewMode == .preview)

                Button("Replace All") {
                    store.replaceAll()
                }
                .disabled(store.settings.viewMode == .preview)
            }

            CommandMenu("Format") {
                Button("Bold") {
                    store.toggleBoldMarkdown()
                }
                .keyboardShortcut("b", modifiers: [.command])
                .disabled(store.settings.viewMode == .preview)

                Button("Italic") {
                    store.toggleItalicMarkdown()
                }
                .keyboardShortcut("i", modifiers: [.command])
                .disabled(store.settings.viewMode == .preview)

                Divider()

                Menu("Lists") {
                    Button("Bullet List") {
                        store.applyListStyle(.bullet)
                    }

                    Button("Numbered List") {
                        store.applyListStyle(.numbered)
                    }

                    Button("Checkbox List") {
                        store.applyListStyle(.checkbox)
                    }
                }
                .disabled(store.settings.viewMode == .preview)

                Menu("Tables") {
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
                }
                .disabled(store.settings.viewMode == .preview)

                Divider()

                Picker("Font", selection: fontSelection) {
                    ForEach(EditorSettings.availableFontNames, id: \.self) { fontName in
                        Text(fontName).tag(fontName)
                    }
                }

                Picker("Font Size", selection: fontSizeSelection) {
                    ForEach(Self.fontSizes, id: \.self) { fontSize in
                        Text("\(Int(fontSize)) pt").tag(fontSize)
                    }
                }
            }

            CommandGroup(after: .toolbar) {
                Button(store.settings.theme == .dark ? "Use Light Theme" : "Use Dark Theme") {
                    store.toggleTheme()
                }
                .keyboardShortcut("t", modifiers: [.command, .option])

                Divider()

                Button("Zoom In") {
                    store.zoomIn()
                }
                .keyboardShortcut("+", modifiers: [.command])

                Button("Zoom Out") {
                    store.zoomOut()
                }
                .keyboardShortcut("-", modifiers: [.command])

                Button("Reset Zoom") {
                    store.resetZoom()
                }
                .keyboardShortcut("0", modifiers: [.command])
            }
        }
    }

    private static let fontSizes: [Double] = [
        9, 10, 11, 12, 13, 14, 15, 16, 18, 20, 22, 24, 28, 32, 36, 48, 60, 72
    ]

    private var fontSelection: Binding<String> {
        Binding(
            get: { store.settings.fontName },
            set: { store.setFontName($0) }
        )
    }

    private var fontSizeSelection: Binding<Double> {
        Binding(
            get: { nearestFontSize(to: store.settings.fontSize) },
            set: { store.setFontSize($0) }
        )
    }

    private var lineNumbersSelection: Binding<Bool> {
        Binding(
            get: { store.settings.showLineNumbers },
            set: { store.setLineNumbersVisible($0) }
        )
    }

    private func nearestFontSize(to fontSize: Double) -> Double {
        Self.fontSizes.min { abs($0 - fontSize) < abs($1 - fontSize) } ?? fontSize
    }
}

private extension EditorTheme {
    var colorScheme: ColorScheme {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}
