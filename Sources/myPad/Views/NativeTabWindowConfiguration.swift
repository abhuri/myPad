import AppKit
import SwiftUI

struct NativeTabWindowConfiguration: NSViewRepresentable {
    var title: String
    var onBecameKey: () -> Void
    var onWillClose: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.onBecameKey = onBecameKey
        context.coordinator.onWillClose = onWillClose

        DispatchQueue.main.async {
            context.coordinator.configure(window: view.window, title: title)
        }

        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.onBecameKey = onBecameKey
        context.coordinator.onWillClose = onWillClose

        DispatchQueue.main.async {
            context.coordinator.configure(window: view.window, title: title)
        }
    }

    final class Coordinator {
        var onBecameKey: () -> Void = {}
        var onWillClose: () -> Void = {}
        private weak var observedWindow: NSWindow?
        private var keyObserver: NSObjectProtocol?
        private var closeObserver: NSObjectProtocol?

        deinit {
            if let keyObserver {
                NotificationCenter.default.removeObserver(keyObserver)
            }

            if let closeObserver {
                NotificationCenter.default.removeObserver(closeObserver)
            }
        }

        func configure(window: NSWindow?, title: String) {
            guard let window else {
                return
            }

            window.title = title
            window.isRestorable = false
            window.tabbingMode = .preferred
            window.tabbingIdentifier = "myPad.notes"

            guard observedWindow !== window else {
                return
            }

            if let keyObserver {
                NotificationCenter.default.removeObserver(keyObserver)
            }

            if let closeObserver {
                NotificationCenter.default.removeObserver(closeObserver)
            }

            observedWindow = window
            keyObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.onBecameKey()
            }
            closeObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.onWillClose()
            }
        }
    }
}
