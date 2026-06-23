import AppKit
import SwiftUI

struct PlainTextEditor: NSViewRepresentable {
    @Binding var text: String
    var settings: EditorSettings
    var onOptionScrollZoom: (CGFloat) -> Void
    var scrollProgress: Double = 0
    var scrollSource: EditorScrollSyncSource = .editor
    var onScrollProgressChange: (Double) -> Void = { _ in }
    var onOpenFileURLs: ([URL]) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            onOptionScrollZoom: onOptionScrollZoom,
            onScrollProgressChange: onScrollProgressChange,
            onOpenFileURLs: onOpenFileURLs
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = ZoomingScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.onOptionScroll = { delta in
            context.coordinator.handleOptionScroll(delta)
        }

        let textView = EditorTextView(frame: .zero)
        textView.string = text
        textView.delegate = context.coordinator
        textView.onMouseDown = { event in
            context.coordinator.toggleCheckbox(at: event)
        }
        textView.onOpenFileURLs = { urls in
            context.coordinator.openFileURLs(urls)
        }
        textView.registerForDraggedTypes([.fileURL])
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isContinuousSpellCheckingEnabled = true
        textView.isAutomaticSpellingCorrectionEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .textColor
        textView.insertionPointColor = .controlAccentColor

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.observeBoundsChanges(in: scrollView)
        configure(textView, in: scrollView)

        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.text = $text
        context.coordinator.onOptionScrollZoom = onOptionScrollZoom
        context.coordinator.onScrollProgressChange = onScrollProgressChange
        context.coordinator.onOpenFileURLs = onOpenFileURLs

        if let scrollView = scrollView as? ZoomingScrollView {
            scrollView.onOptionScroll = { delta in
                context.coordinator.handleOptionScroll(delta)
            }
        }

        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }

        if let textView = textView as? EditorTextView {
            textView.onMouseDown = { event in
                context.coordinator.toggleCheckbox(at: event)
            }
            textView.onOpenFileURLs = { urls in
                context.coordinator.openFileURLs(urls)
            }
        }

        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            context.coordinator.isProgrammaticChange = true
            textView.string = text
            textView.selectedRanges = selectedRanges
            context.coordinator.isProgrammaticChange = false
            textView.needsDisplay = true
            context.coordinator.invalidateLineNumberRuler()
        }

        configure(textView, in: scrollView)

        if scrollSource == .preview {
            context.coordinator.applyScrollProgress(scrollProgress, to: scrollView)
        }
    }

    private func configure(_ textView: NSTextView, in scrollView: NSScrollView) {
        let font = NSFont(name: settings.fontName, size: settings.effectiveFontSize)
            ?? NSFont.monospacedSystemFont(ofSize: settings.effectiveFontSize, weight: .regular)

        textView.font = font
        textView.typingAttributes[.font] = font
        textView.textContainer?.lineFragmentPadding = 0
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .textColor
        scrollView.backgroundColor = .textBackgroundColor
        configureLineNumberRuler(for: textView, in: scrollView, font: font)

        if settings.wordWrap {
            scrollView.hasHorizontalScroller = false
            textView.isHorizontallyResizable = false
            textView.textContainer?.widthTracksTextView = true
            textView.textContainer?.containerSize = NSSize(
                width: scrollView.contentSize.width,
                height: CGFloat.greatestFiniteMagnitude
            )
            textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
            textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textView.autoresizingMask = [.width]
        } else {
            scrollView.hasHorizontalScroller = true
            textView.isHorizontallyResizable = true
            textView.textContainer?.widthTracksTextView = false
            textView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
            textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
            textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textView.autoresizingMask = []
        }
    }

    private func configureLineNumberRuler(for textView: NSTextView, in scrollView: NSScrollView, font: NSFont) {
        guard settings.showLineNumbers else {
            scrollView.hasVerticalRuler = false
            scrollView.rulersVisible = false
            scrollView.verticalRulerView = nil
            return
        }

        let rulerView: LineNumberRulerView
        if let existingRuler = scrollView.verticalRulerView as? LineNumberRulerView {
            rulerView = existingRuler
            rulerView.textView = textView
            rulerView.clientView = textView
        } else {
            rulerView = LineNumberRulerView(textView: textView)
            scrollView.verticalRulerView = rulerView
        }

        rulerView.update(font: font)
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var onOptionScrollZoom: (CGFloat) -> Void
        var onScrollProgressChange: (Double) -> Void
        var onOpenFileURLs: ([URL]) -> Void
        weak var textView: NSTextView?
        var isProgrammaticChange = false
        private var isApplyingExternalScroll = false
        private var lineNumberRulerInvalidationScheduled = false
        private var commandObserver: NSObjectProtocol?
        private var boundsObserver: NSObjectProtocol?
        private weak var observedClipView: NSClipView?
        private let indentUnit = "    "

        init(
            text: Binding<String>,
            onOptionScrollZoom: @escaping (CGFloat) -> Void,
            onScrollProgressChange: @escaping (Double) -> Void,
            onOpenFileURLs: @escaping ([URL]) -> Void
        ) {
            self.text = text
            self.onOptionScrollZoom = onOptionScrollZoom
            self.onScrollProgressChange = onScrollProgressChange
            self.onOpenFileURLs = onOpenFileURLs
            super.init()

            commandObserver = NotificationCenter.default.addObserver(
                forName: .myPadEditorCommand,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let command = notification.object as? EditorCommand else {
                    return
                }

                self?.perform(command)
            }
        }

        deinit {
            if let commandObserver {
                NotificationCenter.default.removeObserver(commandObserver)
            }

            if let boundsObserver {
                NotificationCenter.default.removeObserver(boundsObserver)
            }
        }

        func handleOptionScroll(_ delta: CGFloat) {
            onOptionScrollZoom(delta)
        }

        func openFileURLs(_ urls: [URL]) {
            onOpenFileURLs(urls)
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
            ) { [weak self] _ in
                guard let self else {
                    return
                }

                invalidateLineNumberRuler()

                guard !isApplyingExternalScroll,
                      let scrollView = textView?.enclosingScrollView else {
                    return
                }

                onScrollProgressChange(scrollProgress(in: scrollView))
            }
        }

        func invalidateLineNumberRuler() {
            guard !lineNumberRulerInvalidationScheduled else {
                return
            }

            lineNumberRulerInvalidationScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                lineNumberRulerInvalidationScheduled = false
                textView?.enclosingScrollView?.verticalRulerView?.needsDisplay = true
            }
        }

        func applyScrollProgress(_ progress: Double, to scrollView: NSScrollView) {
            guard let documentView = scrollView.documentView else {
                return
            }

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

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }

            textView.needsDisplay = true
            invalidateLineNumberRuler()

            guard !isProgrammaticChange else {
                return
            }

            text.wrappedValue = textView.string
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.insertNewline(_:)):
                return continueListAfterNewline(in: textView)
            case #selector(NSResponder.insertTab(_:)):
                return adjustListIndent(in: textView, increasing: true)
            case #selector(NSResponder.insertBacktab(_:)):
                return adjustListIndent(in: textView, increasing: false)
            default:
                return false
            }
        }

        func toggleCheckbox(at event: NSEvent) -> Bool {
            guard let textView,
                  let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else {
                return false
            }

            let point = textView.convert(event.locationInWindow, from: nil)
            let textContainerPoint = NSPoint(
                x: point.x - textView.textContainerOrigin.x,
                y: point.y - textView.textContainerOrigin.y
            )
            let glyphIndex = layoutManager.glyphIndex(for: textContainerPoint, in: textContainer)
            let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
            let textLength = (textView.string as NSString).length
            guard characterIndex <= textLength,
                  let listLine = parsedListLine(in: textView.string as NSString, at: characterIndex),
                  listLine.style == .checkbox,
                  NSLocationInRange(characterIndex, listLine.markerRange) else {
                return false
            }

            let nextMarker = listLine.isChecked ? "[ ] " : "[x] "
            textView.insertText(nextMarker, replacementRange: listLine.markerRange)
            textView.setSelectedRange(NSRange(location: listLine.markerRange.location + (nextMarker as NSString).length, length: 0))
            text.wrappedValue = textView.string
            return true
        }

        private func perform(_ command: EditorCommand) {
            guard let textView, textView.window == NSApp.keyWindow || textView.window?.isMainWindow == true else {
                return
            }

            textView.window?.makeFirstResponder(textView)

            switch command {
            case .boldMarkdown:
                toggleMarkdown(delimiter: "**")
            case .italicMarkdown:
                toggleMarkdown(delimiter: "*")
            case .list(let style):
                applyListStyle(style)
            case .insertTable(let rows, let columns):
                insertTable(rows: rows, columns: columns)
            case .formatTable:
                formatTable()
            case .convertSelectionToTable:
                convertSelectionToTable()
            case .findNext(let query):
                findNext(query)
            case .replaceNext(let query, let replacement):
                replaceNext(query: query, replacement: replacement)
            case .replaceAll(let query, let replacement):
                replaceAll(query: query, replacement: replacement)
            }
        }

        private func toggleMarkdown(delimiter: String) {
            guard let textView else {
                return
            }

            let selectedRange = validSelectedRange(in: textView)
            let currentText = textView.string as NSString
            let delimiterLength = (delimiter as NSString).length
            let hasWrappedSelection = selectedRange.length > 0
                && selectedRange.location >= delimiterLength
                && NSMaxRange(selectedRange) + delimiterLength <= currentText.length
                && currentText.substring(
                    with: NSRange(location: selectedRange.location - delimiterLength, length: delimiterLength)
                ) == delimiter
                && currentText.substring(
                    with: NSRange(location: NSMaxRange(selectedRange), length: delimiterLength)
                ) == delimiter

            if hasWrappedSelection {
                let selectedText = currentText.substring(with: selectedRange)
                let replacementRange = NSRange(
                    location: selectedRange.location - delimiterLength,
                    length: selectedRange.length + (delimiterLength * 2)
                )
                textView.insertText(selectedText, replacementRange: replacementRange)
                textView.setSelectedRange(NSRange(location: replacementRange.location, length: selectedRange.length))
            } else {
                let selectedText = currentText.substring(with: selectedRange)
                let replacement = "\(delimiter)\(selectedText)\(delimiter)"
                textView.insertText(replacement, replacementRange: selectedRange)

                let nextSelection = selectedRange.length == 0
                    ? NSRange(location: selectedRange.location + delimiterLength, length: 0)
                    : NSRange(location: selectedRange.location + delimiterLength, length: selectedRange.length)
                textView.setSelectedRange(nextSelection)
            }

            text.wrappedValue = textView.string
        }

        private func insertTable(rows: Int, columns: Int) {
            guard let textView else {
                return
            }

            let selectedRange = validSelectedRange(in: textView)
            let currentText = textView.string as NSString
            let table = MarkdownTableFormatter.makeTable(rows: rows, columns: columns)
            let prefix = needsLeadingNewline(in: currentText, for: selectedRange) ? "\n" : ""
            let suffix = needsTrailingNewline(in: currentText, for: selectedRange) ? "\n" : ""
            let replacement = prefix + table + suffix
            let tableStart = selectedRange.location + (prefix as NSString).length

            textView.insertText(replacement, replacementRange: selectedRange)

            if let firstHeaderRange = MarkdownTableFormatter.firstHeaderRange(in: table) {
                textView.setSelectedRange(NSRange(location: tableStart + firstHeaderRange.location, length: firstHeaderRange.length))
            } else {
                textView.setSelectedRange(NSRange(location: tableStart, length: (table as NSString).length))
            }

            text.wrappedValue = textView.string
        }

        private func formatTable() {
            guard let textView else {
                return
            }

            let selectedRange = validSelectedRange(in: textView)
            guard let result = MarkdownTableFormatter.formatTable(in: textView.string, selectedRange: selectedRange) else {
                NSSound.beep()
                return
            }

            textView.insertText(result.replacement, replacementRange: result.range)
            textView.setSelectedRange(NSRange(location: result.range.location, length: (result.replacement as NSString).length))
            text.wrappedValue = textView.string
        }

        private func convertSelectionToTable() {
            guard let textView else {
                return
            }

            let selectedRange = validSelectedRange(in: textView)
            guard selectedRange.length > 0 else {
                insertTable(rows: 3, columns: 3)
                return
            }

            let selectedText = (textView.string as NSString).substring(with: selectedRange)
            guard let table = MarkdownTableFormatter.convertDelimitedTextToTable(selectedText) else {
                NSSound.beep()
                return
            }

            textView.insertText(table, replacementRange: selectedRange)
            textView.setSelectedRange(NSRange(location: selectedRange.location, length: (table as NSString).length))
            text.wrappedValue = textView.string
        }

        private func findNext(_ query: String) {
            guard let textView,
                  let range = nextRange(matching: query, in: textView) else {
                NSSound.beep()
                return
            }

            textView.setSelectedRange(range)
            textView.scrollRangeToVisible(range)
            textView.window?.makeFirstResponder(textView)
        }

        private func replaceNext(query: String, replacement: String) {
            guard let textView else {
                return
            }

            let selectedRange = validSelectedRange(in: textView)

            if selectedRange.length > 0,
               selectedText(in: textView, matches: query) {
                textView.insertText(replacement, replacementRange: selectedRange)
                let replacementRange = NSRange(location: selectedRange.location, length: (replacement as NSString).length)
                textView.setSelectedRange(replacementRange)
                text.wrappedValue = textView.string
                return
            }

            findNext(query)
        }

        private func replaceAll(query: String, replacement: String) {
            guard let textView, !query.isEmpty else {
                NSSound.beep()
                return
            }

            let mutableString = NSMutableString(string: textView.string)
            let replacementLength = (replacement as NSString).length
            var searchRange = NSRange(location: 0, length: mutableString.length)
            var replacementCount = 0

            while true {
                let foundRange = mutableString.range(
                    of: query,
                    options: [.caseInsensitive, .diacriticInsensitive],
                    range: searchRange
                )

                guard foundRange.location != NSNotFound else {
                    break
                }

                mutableString.replaceCharacters(in: foundRange, with: replacement)
                replacementCount += 1
                let nextLocation = foundRange.location + replacementLength
                searchRange = NSRange(location: nextLocation, length: mutableString.length - nextLocation)
            }

            guard replacementCount > 0 else {
                NSSound.beep()
                return
            }

            textView.insertText(mutableString as String, replacementRange: NSRange(location: 0, length: (textView.string as NSString).length))
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            text.wrappedValue = textView.string
        }

        private func nextRange(matching query: String, in textView: NSTextView) -> NSRange? {
            guard !query.isEmpty else {
                return nil
            }

            let string = textView.string as NSString
            guard string.length > 0 else {
                return nil
            }

            let selectedRange = validSelectedRange(in: textView)
            let searchStart = min(string.length, NSMaxRange(selectedRange))
            let options: NSString.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
            let forwardRange = NSRange(location: searchStart, length: string.length - searchStart)
            let foundForward = string.range(of: query, options: options, range: forwardRange)

            if foundForward.location != NSNotFound {
                return foundForward
            }

            let wrapRange = NSRange(location: 0, length: searchStart)
            let foundWrapped = string.range(of: query, options: options, range: wrapRange)
            return foundWrapped.location == NSNotFound ? nil : foundWrapped
        }

        private func selectedText(in textView: NSTextView, matches query: String) -> Bool {
            guard !query.isEmpty else {
                return false
            }

            let selectedRange = validSelectedRange(in: textView)
            guard selectedRange.length == (query as NSString).length else {
                return false
            }

            let selectedText = (textView.string as NSString).substring(with: selectedRange)
            return selectedText.compare(query, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }

        private func applyListStyle(_ style: EditorListStyle) {
            guard let textView else {
                return
            }

            let currentText = textView.string as NSString
            let selectedRange = validSelectedRange(in: textView)
            let lineRange = currentText.lineRange(for: selectedRange)
            let replacement = listReplacement(
                in: currentText,
                lineRange: lineRange,
                style: style
            )

            textView.insertText(replacement, replacementRange: lineRange)
            textView.setSelectedRange(NSRange(location: lineRange.location, length: (replacement as NSString).length))
            text.wrappedValue = textView.string
        }

        private func listReplacement(
            in text: NSString,
            lineRange: NSRange,
            style: EditorListStyle
        ) -> String {
            var replacement = ""
            var cursor = lineRange.location
            let rangeEnd = NSMaxRange(lineRange)
            var number = 1

            repeat {
                var lineStart = 0
                var lineEnd = 0
                var contentsEnd = 0
                text.getLineStart(
                    &lineStart,
                    end: &lineEnd,
                    contentsEnd: &contentsEnd,
                    for: NSRange(location: min(cursor, text.length), length: 0)
                )

                let lineText = text.substring(with: NSRange(location: lineStart, length: contentsEnd - lineStart))
                let lineEnding = contentsEnd < lineEnd
                    ? text.substring(with: NSRange(location: contentsEnd, length: lineEnd - contentsEnd))
                    : ""

                replacement += lineWithListPrefix(lineText, style: style, number: number) + lineEnding
                number += 1

                if lineEnd >= rangeEnd || lineEnd == cursor {
                    break
                }

                cursor = lineEnd
            } while cursor < rangeEnd || lineRange.length == 0

            return replacement
        }

        private func lineWithListPrefix(_ line: String, style: EditorListStyle, number: Int) -> String {
            let (indent, body) = splitLeadingWhitespace(in: line)
            return indent + listMarker(for: style, number: number) + strippingExistingListMarker(from: body)
        }

        private func splitLeadingWhitespace(in line: String) -> (String, String) {
            let bodyStart = line.firstIndex { character in
                character != " " && character != "\t"
            } ?? line.endIndex

            return (String(line[..<bodyStart]), String(line[bodyStart...]))
        }

        private func strippingExistingListMarker(from body: String) -> String {
            let checkboxMarkers = ["[ ] ", "[] ", "[x] ", "[X] ", "- [ ] ", "- [x] ", "- [X] "]

            for marker in checkboxMarkers where body.hasPrefix(marker) {
                return String(body.dropFirst(marker.count))
            }

            for marker in ["• ", "- ", "* ", "+ "] where body.hasPrefix(marker) {
                return String(body.dropFirst(marker.count))
            }

            if let numbered = numberedMarker(in: body) {
                return String(body.dropFirst(numbered.length))
            }

            return body
        }

        private func listMarker(for style: EditorListStyle, number: Int) -> String {
            switch style {
            case .bullet:
                return "• "
            case .numbered:
                return "\(number). "
            case .checkbox:
                return "[ ] "
            }
        }

        private func continueListAfterNewline(in textView: NSTextView) -> Bool {
            let selectedRange = validSelectedRange(in: textView)
            let currentText = textView.string as NSString
            guard let listLine = parsedListLine(in: currentText, at: selectedRange.location),
                  selectedRange.location >= listLine.markerRange.location else {
                return false
            }

            if listLine.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               selectedRange.location >= listLine.bodyRange.location {
                return finishEmptyListLine(listLine, in: textView)
            }

            let marker = nextMarker(after: listLine)
            textView.insertText("\n\(listLine.indent)\(marker)", replacementRange: selectedRange)
            text.wrappedValue = textView.string
            return true
        }

        private func adjustListIndent(in textView: NSTextView, increasing: Bool) -> Bool {
            let selectedRange = validSelectedRange(in: textView)
            let currentText = textView.string as NSString
            let lineRange = currentText.lineRange(for: selectedRange)
            let replacement = indentationReplacement(
                in: currentText,
                lineRange: lineRange,
                increasing: increasing
            )

            guard replacement.didChange else {
                return false
            }

            textView.insertText(replacement.text, replacementRange: lineRange)

            if selectedRange.length == 0 {
                let nextLocation = max(lineRange.location, selectedRange.location + replacement.cursorDelta)
                textView.setSelectedRange(NSRange(location: nextLocation, length: 0))
            } else {
                textView.setSelectedRange(NSRange(location: lineRange.location, length: (replacement.text as NSString).length))
            }

            text.wrappedValue = textView.string
            return true
        }

        private func indentationReplacement(
            in text: NSString,
            lineRange: NSRange,
            increasing: Bool
        ) -> (text: String, didChange: Bool, cursorDelta: Int) {
            var replacement = ""
            var cursor = lineRange.location
            let rangeEnd = NSMaxRange(lineRange)
            var didChange = false
            var cursorDelta = 0

            repeat {
                var lineStart = 0
                var lineEnd = 0
                var contentsEnd = 0
                text.getLineStart(
                    &lineStart,
                    end: &lineEnd,
                    contentsEnd: &contentsEnd,
                    for: NSRange(location: min(cursor, text.length), length: 0)
                )

                let originalLine = text.substring(with: NSRange(location: lineStart, length: lineEnd - lineStart))
                let contentLine = text.substring(with: NSRange(location: lineStart, length: contentsEnd - lineStart))

                if let listLine = parsedListLine(in: text, at: lineStart) {
                    let adjustedLine: String
                    let delta: Int

                    if listLine.style == .numbered {
                        let numberedAdjustment = adjustedNumberedLine(
                            in: text,
                            originalLine: originalLine,
                            lineStart: lineStart,
                            listLine: listLine,
                            increasing: increasing
                        )
                        adjustedLine = numberedAdjustment.line
                        delta = numberedAdjustment.delta
                    } else {
                        if increasing {
                            adjustedLine = indentUnit + originalLine
                            delta = (indentUnit as NSString).length
                        } else {
                            let outdentCount = removableIndentCount(from: contentLine)
                            adjustedLine = String(originalLine.dropFirst(outdentCount))
                            delta = -outdentCount
                        }
                    }

                    if adjustedLine != originalLine {
                        didChange = true
                        if lineStart <= lineRange.location {
                            cursorDelta += delta
                        }
                    }

                    replacement += adjustedLine
                } else {
                    replacement += originalLine
                }

                if lineEnd >= rangeEnd || lineEnd == cursor {
                    break
                }

                cursor = lineEnd
            } while cursor < rangeEnd || lineRange.length == 0

            return (replacement, didChange, cursorDelta)
        }

        private func finishEmptyListLine(_ listLine: ListLine, in textView: NSTextView) -> Bool {
            let lineContentRange = NSRange(
                location: listLine.lineRange.location,
                length: listLine.contentsEnd - listLine.lineRange.location
            )

            if let promotedPrefix = promotedPrefix(afterEmptyLine: listLine) {
                textView.insertText(promotedPrefix, replacementRange: lineContentRange)
                textView.setSelectedRange(
                    NSRange(location: listLine.lineRange.location + (promotedPrefix as NSString).length, length: 0)
                )
            } else {
                textView.insertText("", replacementRange: lineContentRange)
                textView.setSelectedRange(NSRange(location: listLine.lineRange.location, length: 0))
            }

            text.wrappedValue = textView.string
            return true
        }

        private func promotedPrefix(afterEmptyLine listLine: ListLine) -> String? {
            switch listLine.style {
            case .numbered:
                guard listLine.numberPath.count > 1 else {
                    return nil
                }

                let parentPath = Array(listLine.numberPath.dropLast())
                return numberedPrefix(for: incrementedNumberPath(parentPath))
            case .bullet:
                let depth = listDepth(from: listLine.indent)
                guard depth > 0 else {
                    return nil
                }

                return indent(forDepth: depth - 1) + listMarker(for: .bullet, number: 1)
            case .checkbox:
                let depth = listDepth(from: listLine.indent)
                guard depth > 0 else {
                    return nil
                }

                return indent(forDepth: depth - 1) + listMarker(for: .checkbox, number: 1)
            }
        }

        private func removableIndentCount(from line: String) -> Int {
            guard let first = line.first else {
                return 0
            }

            if first == "\t" {
                return 1
            }

            var count = 0
            for character in line {
                guard character == " ", count < (indentUnit as NSString).length else {
                    break
                }

                count += 1
            }

            return count
        }

        private func adjustedNumberedLine(
            in text: NSString,
            originalLine: String,
            lineStart: Int,
            listLine: ListLine,
            increasing: Bool
        ) -> (line: String, delta: Int) {
            let originalLine = originalLine as NSString
            let prefixRange = NSRange(
                location: 0,
                length: (listLine.markerRange.location - lineStart) + listLine.markerRange.length
            )
            let nextNumberPath: [Int]

            if increasing {
                nextNumberPath = demotedNumberPath(for: listLine, in: text)
            } else {
                guard listLine.numberPath.count > 1 else {
                    return (originalLine as String, 0)
                }

                nextNumberPath = Array(listLine.numberPath.dropLast())
            }

            let prefix = numberedPrefix(for: nextNumberPath)
            let adjustedLine = originalLine.replacingCharacters(in: prefixRange, with: prefix)
            let delta = (prefix as NSString).length - prefixRange.length
            return (adjustedLine, delta)
        }

        private func demotedNumberPath(for listLine: ListLine, in text: NSString) -> [Int] {
            if let previousSibling = previousNumberedSibling(before: listLine.lineRange.location, matching: listLine.numberPath, in: text) {
                return nextChildNumberPath(under: previousSibling.numberPath, before: listLine.lineRange.location, in: text)
            }

            return listLine.numberPath + [1]
        }

        private func nextChildNumberPath(under parentPath: [Int], before lineStart: Int, in text: NSString) -> [Int] {
            var searchLocation = lineStart
            while searchLocation > 0 {
                var previousLineStart = 0
                var previousLineEnd = 0
                var previousContentsEnd = 0
                text.getLineStart(
                    &previousLineStart,
                    end: &previousLineEnd,
                    contentsEnd: &previousContentsEnd,
                    for: NSRange(location: max(0, searchLocation - 1), length: 0)
                )

                if let previousLine = parsedListLine(in: text, at: previousLineStart),
                   previousLine.style == .numbered {
                    if isImmediateChild(previousLine.numberPath, of: parentPath) {
                        return incrementedNumberPath(previousLine.numberPath)
                    }

                    if previousLine.numberPath == parentPath {
                        break
                    }
                }

                if previousLineStart == 0 {
                    break
                }

                searchLocation = previousLineStart
            }

            return parentPath + [1]
        }

        private func previousNumberedSibling(before lineStart: Int, matching numberPath: [Int], in text: NSString) -> ListLine? {
            guard let currentNumber = numberPath.last, currentNumber > 1 else {
                return nil
            }

            var searchLocation = lineStart
            while searchLocation > 0 {
                var previousLineStart = 0
                var previousLineEnd = 0
                var previousContentsEnd = 0
                text.getLineStart(
                    &previousLineStart,
                    end: &previousLineEnd,
                    contentsEnd: &previousContentsEnd,
                    for: NSRange(location: max(0, searchLocation - 1), length: 0)
                )

                if let previousLine = parsedListLine(in: text, at: previousLineStart),
                   previousLine.style == .numbered,
                   isPreviousSibling(previousLine.numberPath, of: numberPath) {
                    return previousLine
                }

                if previousLineStart == 0 {
                    break
                }

                searchLocation = previousLineStart
            }

            return nil
        }

        private func isPreviousSibling(_ candidatePath: [Int], of numberPath: [Int]) -> Bool {
            guard let currentNumber = numberPath.last,
                  let candidateNumber = candidatePath.last,
                  currentNumber > 1,
                  candidateNumber == currentNumber - 1,
                  candidatePath.count == numberPath.count else {
                return false
            }

            return Array(candidatePath.dropLast()) == Array(numberPath.dropLast())
        }

        private func isImmediateChild(_ candidatePath: [Int], of parentPath: [Int]) -> Bool {
            candidatePath.count == parentPath.count + 1
                && Array(candidatePath.prefix(parentPath.count)) == parentPath
        }

        private func nextMarker(after listLine: ListLine) -> String {
            switch listLine.style {
            case .bullet:
                return listMarker(for: .bullet, number: 1)
            case .numbered:
                return numberedMarkerText(for: incrementedNumberPath(listLine.numberPath))
            case .checkbox:
                return listMarker(for: .checkbox, number: 1)
            }
        }

        private func parsedListLine(in text: NSString, at location: Int) -> ListLine? {
            guard text.length > 0 || location == 0 else {
                return nil
            }

            var lineStart = 0
            var lineEnd = 0
            var contentsEnd = 0
            text.getLineStart(
                &lineStart,
                end: &lineEnd,
                contentsEnd: &contentsEnd,
                for: NSRange(location: min(location, text.length), length: 0)
            )

            let contentLength = max(0, contentsEnd - lineStart)
            let lineText = text.substring(with: NSRange(location: lineStart, length: contentLength)) as NSString
            let indentLength = leadingWhitespaceLength(in: lineText)
            let indent = lineText.substring(with: NSRange(location: 0, length: indentLength))
            let markerStart = lineStart + indentLength
            let body = lineText.substring(from: indentLength)

            if let checkbox = checkboxMarker(in: body) {
                let markerRange = NSRange(location: markerStart, length: checkbox.length)
                let bodyRange = NSRange(location: NSMaxRange(markerRange), length: max(0, contentsEnd - NSMaxRange(markerRange)))
                return ListLine(
                    style: .checkbox,
                    indent: indent,
                    markerRange: markerRange,
                    bodyRange: bodyRange,
                    lineRange: NSRange(location: lineStart, length: lineEnd - lineStart),
                    contentsEnd: contentsEnd,
                    body: text.substring(with: bodyRange),
                    numberPath: [1],
                    isChecked: checkbox.isChecked
                )
            }

            for marker in ["• ", "- ", "* ", "+ "] where body.hasPrefix(marker) {
                let markerRange = NSRange(location: markerStart, length: (marker as NSString).length)
                let bodyRange = NSRange(location: NSMaxRange(markerRange), length: max(0, contentsEnd - NSMaxRange(markerRange)))
                return ListLine(
                    style: .bullet,
                    indent: indent,
                    markerRange: markerRange,
                    bodyRange: bodyRange,
                    lineRange: NSRange(location: lineStart, length: lineEnd - lineStart),
                    contentsEnd: contentsEnd,
                    body: text.substring(with: bodyRange),
                    numberPath: [1],
                    isChecked: false
                )
            }

            if let numbered = numberedMarker(in: body) {
                let markerRange = NSRange(location: markerStart, length: numbered.length)
                let bodyRange = NSRange(location: NSMaxRange(markerRange), length: max(0, contentsEnd - NSMaxRange(markerRange)))
                return ListLine(
                    style: .numbered,
                    indent: indent,
                    markerRange: markerRange,
                    bodyRange: bodyRange,
                    lineRange: NSRange(location: lineStart, length: lineEnd - lineStart),
                    contentsEnd: contentsEnd,
                    body: text.substring(with: bodyRange),
                    numberPath: numbered.numberPath,
                    isChecked: false
                )
            }

            return nil
        }

        private func leadingWhitespaceLength(in line: NSString) -> Int {
            var length = 0
            while length < line.length {
                let character = line.substring(with: NSRange(location: length, length: 1))
                guard character == " " || character == "\t" else {
                    break
                }

                length += 1
            }

            return length
        }

        private func checkboxMarker(in body: String) -> (length: Int, isChecked: Bool)? {
            let markers: [(String, Bool)] = [
                ("[ ] ", false),
                ("[] ", false),
                ("[x] ", true),
                ("[X] ", true),
                ("- [ ] ", false),
                ("- [x] ", true),
                ("- [X] ", true)
            ]

            for (marker, isChecked) in markers where body.hasPrefix(marker) {
                return ((marker as NSString).length, isChecked)
            }

            return nil
        }

        private func numberedMarker(in body: String) -> (length: Int, numberPath: [Int])? {
            var index = body.startIndex
            var numberPath: [Int] = []

            while index < body.endIndex {
                let digitStart = index

                while index < body.endIndex, body[index].isNumber {
                    index = body.index(after: index)
                }

                guard digitStart < index,
                      let number = Int(body[digitStart..<index]),
                      index < body.endIndex else {
                    return nil
                }

                numberPath.append(number)

                let punctuation = body[index]
                guard punctuation == "." || (punctuation == ")" && numberPath.count == 1) else {
                    return nil
                }

                index = body.index(after: index)
                guard index < body.endIndex else {
                    return nil
                }

                if body[index] == " " {
                    let markerEnd = body.index(after: index)
                    let marker = String(body[..<markerEnd])
                    return ((marker as NSString).length, numberPath)
                }

                guard punctuation == ".", body[index].isNumber else {
                    return nil
                }
            }

            return nil
        }

        private func numberedMarkerText(for numberPath: [Int]) -> String {
            numberPath
                .map(String.init)
                .joined(separator: ".") + ". "
        }

        private func numberedPrefix(for numberPath: [Int]) -> String {
            indent(forDepth: max(0, numberPath.count - 1)) + numberedMarkerText(for: numberPath)
        }

        private func incrementedNumberPath(_ numberPath: [Int]) -> [Int] {
            guard let last = numberPath.last else {
                return [1]
            }

            var incremented = numberPath
            incremented[incremented.count - 1] = last + 1
            return incremented
        }

        private func indent(forDepth depth: Int) -> String {
            String(repeating: indentUnit, count: max(0, depth))
        }

        private func listDepth(from indent: String) -> Int {
            var depth = 0
            var spaces = 0

            for character in indent {
                if character == "\t" {
                    depth += 1
                    spaces = 0
                } else if character == " " {
                    spaces += 1
                    if spaces == (indentUnit as NSString).length {
                        depth += 1
                        spaces = 0
                    }
                }
            }

            if spaces > 0 {
                depth += 1
            }

            return depth
        }

        private func validSelectedRange(in textView: NSTextView) -> NSRange {
            let selectedRange = textView.selectedRange()
            let textLength = (textView.string as NSString).length

            guard selectedRange.location != NSNotFound else {
                return NSRange(location: textLength, length: 0)
            }

            let location = max(0, min(selectedRange.location, textLength))
            let length = max(0, min(selectedRange.length, textLength - location))
            return NSRange(location: location, length: length)
        }

        private func needsLeadingNewline(in text: NSString, for range: NSRange) -> Bool {
            guard range.location > 0 else {
                return false
            }

            let previousCharacter = text.substring(with: NSRange(location: range.location - 1, length: 1))
            return previousCharacter.rangeOfCharacter(from: .newlines) == nil
        }

        private func needsTrailingNewline(in text: NSString, for range: NSRange) -> Bool {
            let rangeEnd = NSMaxRange(range)
            guard rangeEnd < text.length else {
                return false
            }

            let nextCharacter = text.substring(with: NSRange(location: rangeEnd, length: 1))
            return nextCharacter.rangeOfCharacter(from: .newlines) == nil
        }

        private struct ListLine {
            var style: EditorListStyle
            var indent: String
            var markerRange: NSRange
            var bodyRange: NSRange
            var lineRange: NSRange
            var contentsEnd: Int
            var body: String
            var numberPath: [Int]
            var isChecked: Bool
        }
    }
}

private final class EditorTextView: NSTextView {
    var onMouseDown: ((NSEvent) -> Bool)?
    var onOpenFileURLs: (([URL]) -> Void)?

    override func mouseDown(with event: NSEvent) {
        if onMouseDown?(event) == true {
            return
        }

        super.mouseDown(with: event)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if supportedFileURLs(from: sender.draggingPasteboard).isEmpty {
            return super.draggingEntered(sender)
        }

        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = supportedFileURLs(from: sender.draggingPasteboard)
        guard !urls.isEmpty else {
            return super.performDragOperation(sender)
        }

        onOpenFileURLs?(urls)
        return true
    }

    private func supportedFileURLs(from pasteboard: NSPasteboard) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        let urls = (pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [NSURL] ?? [])
            .compactMap { $0 as URL }

        return urls.filter { url in
            ["txt", "text", "md", "markdown"].contains(url.pathExtension.lowercased())
        }
    }
}

private final class LineNumberRulerView: NSRulerView {
    weak var textView: NSTextView?

    private var labelFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    private var cachedString = ""
    private var cachedUTF16Length = 0
    private var cachedLineStarts = [0]

    override var isFlipped: Bool {
        true
    }

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 40
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        drawHashMarksAndLabels(in: dirtyRect)
    }

    func update(font editorFont: NSFont) {
        labelFont = NSFont.monospacedDigitSystemFont(
            ofSize: max(9, min(72, editorFont.pointSize * 0.85)),
            weight: .regular
        )
        updateLineStartsIfNeeded()
        ruleThickness = preferredThickness()
        needsDisplay = true
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return
        }

        gutterBackgroundColor.setFill()
        bounds.fill()

        updateLineStartsIfNeeded()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        let attributes: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraphStyle
        ]

        let visibleRect = textView.visibleRect
        let containerVisibleRect = NSRect(
            x: visibleRect.minX - textView.textContainerOrigin.x,
            y: visibleRect.minY - textView.textContainerOrigin.y,
            width: visibleRect.width,
            height: visibleRect.height
        )

        let visibleGlyphRange = layoutManager.glyphRange(
            forBoundingRect: containerVisibleRect,
            in: textContainer
        )

        let glyphCount = layoutManager.numberOfGlyphs
        guard glyphCount > 0 else {
            drawLineNumber(1, atY: textView.textContainerOrigin.y - visibleRect.minY, lineHeight: lineHeight(), attributes: attributes)
            return
        }

        guard let clampedVisibleGlyphRange = clampedGlyphRange(visibleGlyphRange, glyphCount: glyphCount) else {
            return
        }

        var glyphIndex = clampedVisibleGlyphRange.location
        let visibleGlyphLimit = NSMaxRange(clampedVisibleGlyphRange)

        while glyphIndex < visibleGlyphLimit {
            var effectiveGlyphRange = NSRange(location: NSNotFound, length: 0)
            let lineRect = layoutManager.lineFragmentRect(
                forGlyphAt: glyphIndex,
                effectiveRange: &effectiveGlyphRange
            )

            guard let lineGlyphRange = clampedGlyphRange(effectiveGlyphRange, glyphCount: glyphCount),
                  NSMaxRange(lineGlyphRange) > glyphIndex else {
                return
            }

            let characterRange = layoutManager.characterRange(forGlyphRange: lineGlyphRange, actualGlyphRange: nil)
            let characterIndex = characterRange.location
            if characterIndex != NSNotFound,
               characterIndex <= cachedUTF16Length,
               isLogicalLineStart(characterIndex) {
                let y = textView.textContainerOrigin.y + lineRect.minY - visibleRect.minY
                drawLineNumber(
                    lineNumber(for: characterIndex),
                    atY: y,
                    lineHeight: lineRect.height,
                    attributes: attributes
                )
            }

            glyphIndex = NSMaxRange(lineGlyphRange)
        }
    }

    private func drawLineNumber(
        _ number: Int,
        atY y: CGFloat,
        lineHeight: CGFloat,
        attributes: [NSAttributedString.Key: Any]
    ) {
        let labelHeight = self.lineHeight()
        let labelRect = NSRect(
            x: 0,
            y: y + max(0, (lineHeight - labelHeight) / 2),
            width: max(0, bounds.width - 8),
            height: labelHeight
        )
        NSString(string: "\(number)").draw(in: labelRect, withAttributes: attributes)
    }

    private func preferredThickness() -> CGFloat {
        let digits = max(2, String(cachedLineStarts.count).count)
        let sample = NSString(string: String(repeating: "8", count: digits))
        let width = sample.size(withAttributes: [.font: labelFont]).width
        return ceil(width + 18)
    }

    private var gutterBackgroundColor: NSColor {
        let bestMatch = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])

        if bestMatch == .darkAqua {
            return NSColor(calibratedWhite: 0.15, alpha: 1)
        }

        return NSColor(calibratedWhite: 0.965, alpha: 1)
    }

    private func lineHeight() -> CGFloat {
        ceil(labelFont.ascender - labelFont.descender + labelFont.leading + 2)
    }

    private func clampedGlyphRange(_ range: NSRange, glyphCount: Int) -> NSRange? {
        guard range.location != NSNotFound,
              range.length > 0,
              glyphCount > 0 else {
            return nil
        }

        let lowerBound = max(0, min(range.location, glyphCount))
        let upperBound = max(lowerBound, min(NSMaxRange(range), glyphCount))
        guard lowerBound < upperBound else {
            return nil
        }

        return NSRange(location: lowerBound, length: upperBound - lowerBound)
    }

    private func isLogicalLineStart(_ characterIndex: Int) -> Bool {
        let index = lineIndex(containing: characterIndex)
        return cachedLineStarts[index] == max(0, min(characterIndex, cachedUTF16Length))
    }

    private func lineNumber(for characterIndex: Int) -> Int {
        lineIndex(containing: characterIndex) + 1
    }

    private func lineIndex(containing characterIndex: Int) -> Int {
        updateLineStartsIfNeeded()

        let target = max(0, min(characterIndex, cachedUTF16Length))
        var low = 0
        var high = cachedLineStarts.count

        while low < high {
            let middle = (low + high) / 2
            if cachedLineStarts[middle] <= target {
                low = middle + 1
            } else {
                high = middle
            }
        }

        return max(0, low - 1)
    }

    private func updateLineStartsIfNeeded() {
        guard let string = textView?.string else {
            cachedString = ""
            cachedUTF16Length = 0
            cachedLineStarts = [0]
            return
        }

        guard string != cachedString else {
            return
        }

        cachedString = string
        let nsString = string as NSString
        cachedUTF16Length = nsString.length
        var starts = [0]
        var searchStart = 0

        while searchStart < nsString.length {
            let searchRange = NSRange(location: searchStart, length: nsString.length - searchStart)
            let newlineRange = nsString.rangeOfCharacter(from: .newlines, options: [], range: searchRange)

            guard newlineRange.location != NSNotFound else {
                break
            }

            searchStart = newlineRange.location + newlineRange.length
            starts.append(searchStart)
        }

        cachedLineStarts = starts
    }
}

private final class ZoomingScrollView: NSScrollView {
    var onOptionScroll: ((CGFloat) -> Void)?
    private var preciseScrollRemainder: CGFloat = 0

    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.option) {
            let delta = event.scrollingDeltaY != 0 ? event.scrollingDeltaY : event.deltaY

            guard delta != 0 else {
                return
            }

            if event.hasPreciseScrollingDeltas {
                preciseScrollRemainder += delta

                guard abs(preciseScrollRemainder) >= 8 else {
                    return
                }

                onOptionScroll?(preciseScrollRemainder > 0 ? 1 : -1)
                preciseScrollRemainder = 0
            } else {
                onOptionScroll?(delta > 0 ? 1 : -1)
            }

            return
        }

        preciseScrollRemainder = 0
        super.scrollWheel(with: event)
    }
}
