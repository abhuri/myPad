import AppKit
import Foundation

struct EditorSettings: Codable, Equatable {
    var fontName: String = "Menlo"
    var fontSize: Double = 15
    var wordWrap: Bool = true
    var zoom: Double = 1

    var effectiveFontSize: CGFloat {
        max(9, min(72, fontSize * zoom))
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
