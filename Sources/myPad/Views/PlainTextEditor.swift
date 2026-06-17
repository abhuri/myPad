import AppKit
import SwiftUI

struct PlainTextEditor: NSViewRepresentable {
    @Binding var text: String
    var settings: EditorSettings
    var onOptionScrollZoom: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onOptionScrollZoom: onOptionScrollZoom)
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
        configure(textView, in: scrollView)

        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.text = $text
        context.coordinator.onOptionScrollZoom = onOptionScrollZoom

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
        }

        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            context.coordinator.isProgrammaticChange = true
            textView.string = text
            textView.selectedRanges = selectedRanges
            context.coordinator.isProgrammaticChange = false
        }

        configure(textView, in: scrollView)
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

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var onOptionScrollZoom: (CGFloat) -> Void
        weak var textView: NSTextView?
        var isProgrammaticChange = false
        private var commandObserver: NSObjectProtocol?
        private let indentUnit = "    "

        init(text: Binding<String>, onOptionScrollZoom: @escaping (CGFloat) -> Void) {
            self.text = text
            self.onOptionScrollZoom = onOptionScrollZoom
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
        }

        func handleOptionScroll(_ delta: CGFloat) {
            onOptionScrollZoom(delta)
        }

        func textDidChange(_ notification: Notification) {
            guard !isProgrammaticChange, let textView = notification.object as? NSTextView else {
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

    override func mouseDown(with event: NSEvent) {
        if onMouseDown?(event) == true {
            return
        }

        super.mouseDown(with: event)
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
