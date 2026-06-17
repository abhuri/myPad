import { markdown } from "@codemirror/lang-markdown";
import { defaultKeymap, history, historyKeymap } from "@codemirror/commands";
import { Compartment, EditorSelection, EditorState, type Extension } from "@codemirror/state";
import { EditorView, keymap, lineNumbers } from "@codemirror/view";
import { forwardRef, useEffect, useImperativeHandle, useMemo, useRef } from "react";
import type { EditorListStyle, EditorSettings } from "../lib/types";
import {
  adjustListIndent,
  applyListStyle,
  continueListAfterNewline,
  toggleCheckboxAt,
  toggleMarkdown,
} from "../lib/listTransforms";

export interface EditorHandle {
  focus: () => void;
  toggleBold: () => void;
  toggleItalic: () => void;
  applyListStyle: (style: EditorListStyle) => void;
}

interface EditorProps {
  noteID: string;
  text: string;
  settings: EditorSettings;
  onChange: (content: string) => void;
  onOptionScrollZoom: (delta: number) => void;
}

const wrapCompartment = new Compartment();
const themeCompartment = new Compartment();
const fontCompartment = new Compartment();

export const Editor = forwardRef<EditorHandle, EditorProps>(function Editor(
  { noteID, text, settings, onChange, onOptionScrollZoom },
  ref
) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const viewRef = useRef<EditorView | null>(null);
  const onChangeRef = useRef(onChange);
  const onOptionScrollZoomRef = useRef(onOptionScrollZoom);
  const textRef = useRef(text);

  onChangeRef.current = onChange;
  onOptionScrollZoomRef.current = onOptionScrollZoom;
  textRef.current = text;

  const extensions = useMemo<Extension[]>(
    () => [
      lineNumbers(),
      history(),
      markdown(),
      keymap.of([
        {
          key: "Mod-b",
          run: (view) => applyTransform(view, (content, selection) => toggleMarkdown(content, selection, "**")),
        },
        {
          key: "Mod-i",
          run: (view) => applyTransform(view, (content, selection) => toggleMarkdown(content, selection, "*")),
        },
        {
          key: "Enter",
          run: (view) => applyTransform(view, (content, selection) => continueListAfterNewline(content, selection.from)),
        },
        {
          key: "Tab",
          run: (view) => applyTransform(view, (content, selection) => adjustListIndent(content, selection, true)),
        },
        {
          key: "Shift-Tab",
          run: (view) => applyTransform(view, (content, selection) => adjustListIndent(content, selection, false)),
        },
        ...historyKeymap,
        ...defaultKeymap,
      ]),
      EditorView.updateListener.of((update) => {
        if (update.docChanged) {
          onChangeRef.current(update.state.doc.toString());
        }
      }),
      EditorView.domEventHandlers({
        mousedown: (event, view) => {
          const position = view.posAtCoords({ x: event.clientX, y: event.clientY });

          if (position === null) {
            return false;
          }

          const edit = toggleCheckboxAt(view.state.doc.toString(), position);

          if (!edit.handled) {
            return false;
          }

          applyEdit(view, edit.text, edit.selection);
          event.preventDefault();
          return true;
        },
        wheel: (event) => {
          if (!event.altKey) {
            return false;
          }

          const delta = event.deltaY < 0 ? 1 : -1;
          onOptionScrollZoomRef.current(delta);
          event.preventDefault();
          return true;
        },
      }),
      wrapCompartment.of(settings.wordWrap ? EditorView.lineWrapping : []),
      fontCompartment.of(fontTheme(settings)),
      themeCompartment.of(editorTheme(settings.theme)),
    ],
    []
  );

  useEffect(() => {
    if (!containerRef.current) {
      return undefined;
    }

    const view = new EditorView({
      state: EditorState.create({
        doc: text,
        extensions,
      }),
      parent: containerRef.current,
    });

    viewRef.current = view;
    view.focus();

    return () => {
      view.destroy();
      viewRef.current = null;
    };
  }, [extensions, noteID]);

  useEffect(() => {
    const view = viewRef.current;

    if (!view) {
      return;
    }

    const currentText = view.state.doc.toString();
    if (currentText === text) {
      return;
    }

    const selection = view.state.selection.main;
    view.dispatch({
      changes: { from: 0, to: currentText.length, insert: text },
      selection: EditorSelection.range(
        Math.min(selection.anchor, text.length),
        Math.min(selection.head, text.length)
      ),
    });
  }, [text]);

  useEffect(() => {
    const view = viewRef.current;

    if (!view) {
      return;
    }

    view.dispatch({
      effects: [
        wrapCompartment.reconfigure(settings.wordWrap ? EditorView.lineWrapping : []),
        fontCompartment.reconfigure(fontTheme(settings)),
        themeCompartment.reconfigure(editorTheme(settings.theme)),
      ],
    });
  }, [settings.fontName, settings.fontSize, settings.theme, settings.wordWrap, settings.zoom]);

  useImperativeHandle(
    ref,
    () => ({
      focus: () => viewRef.current?.focus(),
      toggleBold: () => {
        const view = viewRef.current;
        if (view) {
          applyTransform(view, (content, selection) => toggleMarkdown(content, selection, "**"));
        }
      },
      toggleItalic: () => {
        const view = viewRef.current;
        if (view) {
          applyTransform(view, (content, selection) => toggleMarkdown(content, selection, "*"));
        }
      },
      applyListStyle: (style) => {
        const view = viewRef.current;
        if (view) {
          applyTransform(view, (content, selection) => applyListStyle(content, selection, style));
        }
      },
    }),
    []
  );

  return <div className="editorHost" ref={containerRef} />;
});

function applyTransform(
  view: EditorView,
  transform: (content: string, selection: { from: number; to: number }) => { text: string; selection: { from: number; to: number }; handled: boolean }
): boolean {
  const currentText = view.state.doc.toString();
  const selection = view.state.selection.main;
  const edit = transform(currentText, { from: selection.from, to: selection.to });

  if (!edit.handled) {
    return false;
  }

  applyEdit(view, edit.text, edit.selection);
  return true;
}

function applyEdit(view: EditorView, text: string, selection: { from: number; to: number }): void {
  view.dispatch({
    changes: { from: 0, to: view.state.doc.length, insert: text },
    selection: EditorSelection.range(selection.from, selection.to),
    scrollIntoView: true,
  });
  view.focus();
}

function fontTheme(settings: EditorSettings): Extension {
  const fontSize = Math.max(9, Math.min(72, settings.fontSize * settings.zoom));
  const fontFamily = fontStack(settings.fontName);

  return EditorView.theme({
    "&": {
      height: "100%",
      fontSize: `${fontSize}px`,
      fontFamily,
    },
    ".cm-scroller": {
      fontFamily,
      lineHeight: "1.52",
    },
    ".cm-content": {
      padding: "14px 16px",
    },
    ".cm-line": {
      padding: "0",
    },
    ".cm-gutters": {
      padding: "8px 0",
    },
  });
}

function editorTheme(theme: "light" | "dark"): Extension {
  const isDark = theme === "dark";

  return EditorView.theme({
    "&": {
      backgroundColor: isDark ? "#17191f" : "#ffffff",
      color: isDark ? "#eef1f7" : "#1d2430",
    },
    ".cm-content": {
      caretColor: "#2f6fed",
    },
    ".cm-cursor": {
      borderLeftColor: "#2f6fed",
    },
    ".cm-selectionBackground, &.cm-focused .cm-selectionBackground": {
      backgroundColor: isDark ? "rgba(70, 130, 230, 0.35)" : "rgba(47, 111, 237, 0.18)",
    },
    ".cm-activeLine": {
      backgroundColor: isDark ? "rgba(255, 255, 255, 0.045)" : "rgba(47, 111, 237, 0.045)",
    },
    ".cm-gutters": {
      backgroundColor: isDark ? "#15171c" : "#f4f6fa",
      color: isDark ? "#7f8796" : "#8a93a4",
      borderRight: isDark ? "1px solid #2a2f39" : "1px solid #d9dee8",
    },
    ".cm-activeLineGutter": {
      backgroundColor: isDark ? "#20242d" : "#e9eef8",
      color: isDark ? "#d6dbe6" : "#41506a",
    },
    ".cm-focused": {
      outline: "none",
    },
  });
}

function fontStack(fontName: string): string {
  const quoted = fontName.includes(" ") ? `"${fontName}"` : fontName;
  return `${quoted}, "SF Mono", "Cascadia Code", "Ubuntu Mono", "DejaVu Sans Mono", monospace`;
}
