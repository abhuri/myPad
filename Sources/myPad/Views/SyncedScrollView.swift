import AppKit
import SwiftUI

struct SyncedScrollView<Content: View>: NSViewRepresentable {
    var scrollProgress: Double
    var scrollSource: EditorScrollSyncSource
    var selfSource: EditorScrollSyncSource
    var onScrollProgressChange: (Double) -> Void
    var content: Content

    init(
        scrollProgress: Double,
        scrollSource: EditorScrollSyncSource,
        selfSource: EditorScrollSyncSource,
        onScrollProgressChange: @escaping (Double) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.scrollProgress = scrollProgress
        self.scrollSource = scrollSource
        self.selfSource = selfSource
        self.onScrollProgressChange = onScrollProgressChange
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScrollProgressChange: onScrollProgressChange)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let hostingView = NSHostingView(rootView: content)
        hostingView.isFlipped = true
        hostingView.translatesAutoresizingMaskIntoConstraints = true
        scrollView.documentView = hostingView
        context.coordinator.hostingView = hostingView
        context.coordinator.observeBoundsChanges(in: scrollView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.onScrollProgressChange = onScrollProgressChange
        context.coordinator.hostingView?.rootView = content
        context.coordinator.resizeDocument(in: scrollView)

        if scrollSource != selfSource {
            context.coordinator.applyScrollProgress(scrollProgress, to: scrollView)
        }
    }

    final class Coordinator: NSObject {
        var onScrollProgressChange: (Double) -> Void
        weak var hostingView: NSHostingView<Content>?
        private var boundsObserver: NSObjectProtocol?
        private weak var observedClipView: NSClipView?
        private var isApplyingExternalScroll = false

        init(onScrollProgressChange: @escaping (Double) -> Void) {
            self.onScrollProgressChange = onScrollProgressChange
        }

        deinit {
            if let boundsObserver {
                NotificationCenter.default.removeObserver(boundsObserver)
            }
        }

        func observeBoundsChanges(in scrollView: NSScrollView) {
            guard observedClipView !== scrollView.contentView else {
                return
            }

            if let boundsObserver {
                NotificationCenter.default.removeObserver(boundsObserver)
            }

            let clipView = scrollView.contentView
            observedClipView = clipView
            clipView.postsBoundsChangedNotifications = true
            boundsObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: clipView,
                queue: .main
            ) { [weak self, weak scrollView] _ in
                guard let self, let scrollView, !isApplyingExternalScroll else {
                    return
                }

                onScrollProgressChange(scrollProgress(in: scrollView))
            }
        }

        func resizeDocument(in scrollView: NSScrollView) {
            guard let hostingView else {
                return
            }

            let width = max(scrollView.contentSize.width, 1)
            let fittingSize = hostingView.fittingSize
            hostingView.frame = NSRect(
                x: 0,
                y: 0,
                width: width,
                height: max(scrollView.contentSize.height, fittingSize.height)
            )
        }

        func applyScrollProgress(_ progress: Double, to scrollView: NSScrollView) {
            guard let documentView = scrollView.documentView else {
                return
            }

            resizeDocument(in: scrollView)
            let clampedProgress = max(0, min(1, progress))
            let maxY = max(0, documentView.bounds.height - scrollView.contentView.bounds.height)
            let targetY = maxY * clampedProgress
            let currentY = scrollView.contentView.bounds.origin.y

            guard abs(currentY - targetY) > 1 else {
                return
            }

            isApplyingExternalScroll = true
            scrollView.contentView.scroll(to: NSPoint(x: scrollView.contentView.bounds.origin.x, y: targetY))
            scrollView.reflectScrolledClipView(scrollView.contentView)
            isApplyingExternalScroll = false
        }

        private func scrollProgress(in scrollView: NSScrollView) -> Double {
            guard let documentView = scrollView.documentView else {
                return 0
            }

            let maxY = max(0, documentView.bounds.height - scrollView.contentView.bounds.height)
            guard maxY > 0 else {
                return 0
            }

            return max(0, min(1, scrollView.contentView.bounds.origin.y / maxY))
        }
    }
}
