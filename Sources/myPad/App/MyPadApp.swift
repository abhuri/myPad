import AppKit
import SwiftUI

@main
struct MyPadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = NoteStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .frame(minWidth: 720, minHeight: 460)
                .preferredColorScheme(store.settings.theme.colorScheme)
                .onAppear {
                    store.ensureReady()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    store.saveNow()
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Tab") {
                    store.createNote()
                }
                .keyboardShortcut("n", modifiers: [.command])
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

            CommandMenu("Note") {
                Button("Close Tab") {
                    store.closeSelectedNote()
                }
                .keyboardShortcut("w", modifiers: [.command])

                Divider()

                Button(store.settings.wordWrap ? "Turn Word Wrap Off" : "Turn Word Wrap On") {
                    store.setWordWrap(!store.settings.wordWrap)
                }
                .keyboardShortcut("w", modifiers: [.command, .option])

                Toggle("Show Line Numbers", isOn: lineNumbersSelection)
                    .keyboardShortcut("l", modifiers: [.command, .option])
            }

            CommandMenu("Format") {
                Button("Bold") {
                    store.toggleBoldMarkdown()
                }
                .keyboardShortcut("b", modifiers: [.command])

                Button("Italic") {
                    store.toggleItalicMarkdown()
                }
                .keyboardShortcut("i", modifiers: [.command])

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
