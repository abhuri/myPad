import AppKit
import SwiftUI

struct MacWindowTabBarSuppressor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = WindowProbeView()
        DispatchQueue.main.async {
            suppressMacWindowTabBar(for: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            suppressMacWindowTabBar(for: nsView.window)
        }
    }
}

private func suppressMacWindowTabBar(for window: NSWindow?) {
    guard let window else {
        return
    }

    window.tabbingMode = .disallowed

    if window.tabGroup?.isTabBarVisible == true {
        window.toggleTabBar(nil)
    }
}

private final class WindowProbeView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        DispatchQueue.main.async { [weak self] in
            suppressMacWindowTabBar(for: self?.window)
        }
    }
}
