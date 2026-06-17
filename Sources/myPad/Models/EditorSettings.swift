import AppKit
import Foundation

enum EditorTheme: String, Codable, Equatable, CaseIterable, Identifiable {
    case light
    case dark

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }
}

enum EditorListStyle {
    case bullet
    case numbered
    case checkbox
}

enum EditorCommand {
    case boldMarkdown
    case italicMarkdown
    case list(EditorListStyle)
}

extension Notification.Name {
    static let myPadEditorCommand = Notification.Name("myPadEditorCommand")
}

struct EditorSettings: Codable, Equatable {
    var fontName: String = "Menlo"
    var fontSize: Double = 15
    var wordWrap: Bool = true
    var showLineNumbers: Bool = false
    var zoom: Double = 1
    var theme: EditorTheme = .light

    var effectiveFontSize: CGFloat {
        max(9, min(72, fontSize * zoom))
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fontName = try container.decodeIfPresent(String.self, forKey: .fontName) ?? "Menlo"
        fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? 15
        wordWrap = try container.decodeIfPresent(Bool.self, forKey: .wordWrap) ?? true
        showLineNumbers = try container.decodeIfPresent(Bool.self, forKey: .showLineNumbers) ?? false
        zoom = try container.decodeIfPresent(Double.self, forKey: .zoom) ?? 1
        theme = try container.decodeIfPresent(EditorTheme.self, forKey: .theme) ?? .light
    }

    static let availableFontNames: [String] = {
        let preferred = [
            "Menlo",
            "Monaco",
            "SF Mono",
            "Courier New",
            "Helvetica Neue",
            "Arial",
            "Avenir Next",
            "Georgia",
            "Times New Roman"
        ]
        let installed = Set(NSFontManager.shared.availableFontFamilies)
        let preferredInstalled = preferred.filter { installed.contains($0) }
        let rest = installed
            .subtracting(preferredInstalled)
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        return preferredInstalled + rest
    }()
}
