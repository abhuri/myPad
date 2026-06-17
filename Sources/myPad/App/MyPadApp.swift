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
            }

            CommandMenu("View") {
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
}
