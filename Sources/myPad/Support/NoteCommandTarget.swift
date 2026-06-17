import Foundation
import SwiftUI

struct NoteCommandTarget {
    let store: NoteStore
    let noteID: UUID
}

private struct NoteCommandTargetKey: FocusedValueKey {
    typealias Value = NoteCommandTarget
}

extension FocusedValues {
    var noteCommandTarget: NoteCommandTarget? {
        get { self[NoteCommandTargetKey.self] }
        set { self[NoteCommandTargetKey.self] = newValue }
    }
}
