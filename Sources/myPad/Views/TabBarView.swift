import SwiftUI

struct TabBarView: View {
    @ObservedObject var store: NoteStore

    var body: some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(store.notes) { note in
                        TabItemView(
                            note: note,
                            isSelected: note.id == store.selectedNote?.id,
                            select: { store.select(noteID: note.id) },
                            close: { close(note) }
                        )
                    }

                    NewTabItemView {
                        store.createNote()
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .frame(height: 36)
        .background(.bar)
    }

    private func close(_ note: Note) {
        if note.id != store.selectedNote?.id {
            store.select(noteID: note.id)
        }

        store.closeSelectedNote()
    }
}

private struct TabItemView: View {
    let note: Note
    let isSelected: Bool
    let select: () -> Void
    let close: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Text(note.title)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 180, alignment: .leading)

            if isSelected || isHovering {
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.borderless)
                .help("Close Tab")
            }
        }
        .font(.system(size: 12))
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .frame(height: 28)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: select)
        .onHover { isHovering = $0 }
    }

    private var background: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(Color(nsColor: .selectedContentBackgroundColor).opacity(0.18))
        }

        if isHovering {
            return AnyShapeStyle(Color.secondary.opacity(0.08))
        }

        return AnyShapeStyle(Color.clear)
    }
}

private struct NewTabItemView: View {
    let create: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: create) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 34, height: 28)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("New Tab")
        .onHover { isHovering = $0 }
    }

    private var background: some ShapeStyle {
        if isHovering {
            return AnyShapeStyle(Color.secondary.opacity(0.1))
        }

        return AnyShapeStyle(Color.secondary.opacity(0.04))
    }
}
