import {
  Bold,
  CheckSquare,
  FilePlus,
  Italic,
  List,
  ListOrdered,
  Minus,
  Moon,
  Plus,
  Save,
  Sun,
  TextQuote,
  WrapText,
  X,
} from "lucide-react";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Editor, type EditorHandle } from "./components/Editor";
import { createNote, defaultSession, isoDate, lineCount, noteTitle, normalizeSession } from "./lib/session";
import { chooseSavePath, closeAppWindow, loadSession, saveNoteToPath, saveSession, sessionPath } from "./lib/storage";
import type { EditorListStyle, Note, SaveState, SessionState } from "./lib/types";

const fontOptions = [
  "Menlo",
  "Monaco",
  "SF Mono",
  "Courier New",
  "Ubuntu Mono",
  "DejaVu Sans Mono",
  "Arial",
  "Georgia",
];

const fontSizes = [9, 10, 11, 12, 13, 14, 15, 16, 18, 20, 22, 24, 28, 32, 36, 48, 60, 72];

export function App() {
  const [state, setState] = useState<SessionState>(() => defaultSession());
  const [isReady, setIsReady] = useState(false);
  const [saveState, setSaveState] = useState<SaveState>("Saved");
  const [saveToast, setSaveToast] = useState("");
  const [activeMenu, setActiveMenu] = useState<"lists" | null>(null);
  const [storedSessionPath, setStoredSessionPath] = useState("");
  const editorRef = useRef<EditorHandle | null>(null);
  const saveTimerRef = useRef<number | null>(null);
  const saveToastTimerRef = useRef<number | null>(null);

  const selectedNote = useMemo(
    () => state.notes.find((note) => note.id === state.selectedNoteID) ?? state.notes[0],
    [state.notes, state.selectedNoteID]
  );

  const persist = useCallback(
    async (nextState: SessionState, mode: "soon" | "now" = "soon") => {
      if (!isReady) {
        return;
      }

      if (saveTimerRef.current !== null) {
        window.clearTimeout(saveTimerRef.current);
        saveTimerRef.current = null;
      }

      const commit = async () => {
        setSaveState("Saving...");
        try {
          await saveSession(nextState);
          setSaveState("Saved");
        } catch {
          setSaveState("Save failed");
        }
      };

      if (mode === "now") {
        await commit();
        return;
      }

      setSaveState("Saving...");
      saveTimerRef.current = window.setTimeout(commit, 200);
    },
    [isReady]
  );

  const updateState = useCallback(
    (updater: (previous: SessionState) => SessionState, mode: "soon" | "now" = "soon") => {
      setState((previous) => {
        const next = normalizeSession(updater(previous));
        void persist(next, mode);
        return next;
      });
    },
    [persist]
  );

  useEffect(() => {
    let isMounted = true;

    async function boot() {
      try {
        const loaded = await loadSession();
        if (isMounted) {
          setState(loaded);
          setSaveState("Saved");
          setStoredSessionPath(await sessionPath());
        }
      } catch {
        if (isMounted) {
          const fallback = defaultSession();
          setState(fallback);
          setSaveState("Save failed");
        }
      } finally {
        if (isMounted) {
          setIsReady(true);
        }
      }
    }

    void boot();

    return () => {
      isMounted = false;
    };
  }, []);

  useEffect(() => {
    const flush = () => {
      void saveSession(state);
    };

    window.addEventListener("beforeunload", flush);
    document.addEventListener("visibilitychange", flush);

    return () => {
      window.removeEventListener("beforeunload", flush);
      document.removeEventListener("visibilitychange", flush);
    };
  }, [state]);

  useEffect(() => {
    return () => {
      if (saveToastTimerRef.current !== null) {
        window.clearTimeout(saveToastTimerRef.current);
      }
    };
  }, []);

  useEffect(() => {
    document.documentElement.dataset.theme = state.settings.theme;
  }, [state.settings.theme]);

  const createNewNote = () => {
    const note = createNote();
    updateState((previous) => ({
      ...previous,
      notes: [...previous.notes, note],
      selectedNoteID: note.id,
    }));
  };

  const selectNote = (noteID: string) => {
    updateState((previous) => ({
      ...previous,
      selectedNoteID: noteID,
    }));
  };

  const closeNote = (noteID: string) => {
    updateState((previous) => {
      const closingIndex = previous.notes.findIndex((note) => note.id === noteID);

      if (previous.notes.length === 1) {
        void closeAppWindow();
        return previous;
      }

      const notes = previous.notes.filter((note) => note.id !== noteID);
      const selectedNoteID =
        previous.selectedNoteID === noteID
          ? notes[Math.min(closingIndex, notes.length - 1)]?.id
          : previous.selectedNoteID;

      return {
        ...previous,
        notes,
        selectedNoteID,
      };
    });
  };

  const updateSelectedContent = (content: string) => {
    if (!selectedNote || selectedNote.content === content) {
      return;
    }

    updateState((previous) => ({
      ...previous,
      notes: previous.notes.map((note) =>
        note.id === selectedNote.id ? { ...note, content, updatedAt: isoDate() } : note
      ),
    }));
  };

  const setSetting = <Key extends keyof SessionState["settings"]>(key: Key, value: SessionState["settings"][Key]) => {
    updateState((previous) => ({
      ...previous,
      settings: {
        ...previous.settings,
        [key]: value,
      },
    }));
  };

  const zoomBy = (delta: number) => {
    updateState((previous) => ({
      ...previous,
      settings: {
        ...previous.settings,
        zoom: Math.max(0.5, Math.min(3, Number((previous.settings.zoom + delta).toFixed(2)))),
      },
    }));
  };

  const showSavedToast = () => {
    if (saveToastTimerRef.current !== null) {
      window.clearTimeout(saveToastTimerRef.current);
    }

    setSaveToast("Saved");
    saveToastTimerRef.current = window.setTimeout(() => {
      setSaveToast("");
      saveToastTimerRef.current = null;
    }, 1600);
  };

  const saveCurrentNote = async () => {
    if (!selectedNote) {
      return;
    }

    if (!selectedNote.filePath) {
      await saveCurrentNoteAs();
      return;
    }

    try {
      await saveNoteToPath(selectedNote.filePath, selectedNote.content);
      await persist(state, "now");
      setSaveState("Saved to file");
      showSavedToast();
    } catch {
      setSaveState("File save failed");
    }
  };

  const saveCurrentNoteAs = async () => {
    if (!selectedNote) {
      return;
    }

    const path = await chooseSavePath(suggestedFileName(selectedNote));

    if (!path) {
      return;
    }

    const normalizedPath = ensureWritableExtension(path);

    try {
      await saveNoteToPath(normalizedPath, selectedNote.content);
      const nextState = normalizeSession({
        ...state,
        notes: state.notes.map((note) =>
          note.id === selectedNote.id ? { ...note, filePath: normalizedPath, updatedAt: isoDate() } : note
        ),
      });
      setState(nextState);
      await persist(nextState, "now");
      setSaveState("Saved to file");
      showSavedToast();
    } catch {
      setSaveState("File save failed");
    }
  };

  const runEditorCommand = (command: "bold" | "italic" | EditorListStyle) => {
    editorRef.current?.focus();

    if (command === "bold") {
      editorRef.current?.toggleBold();
    } else if (command === "italic") {
      editorRef.current?.toggleItalic();
    } else {
      editorRef.current?.applyListStyle(command);
    }
  };

  const runListCommand = (style: EditorListStyle) => {
    runEditorCommand(style);
    setActiveMenu(null);
  };

  if (!isReady || !selectedNote) {
    return (
      <main className="appShell">
        <div className="loadingPane">Loading myPad...</div>
      </main>
    );
  }

  return (
    <main className="appShell">
      <header className="tabBar" aria-label="Note tabs">
        <div className="tabsScroller">
          {state.notes.map((note) => (
            <div
              className={`tabItem ${note.id === selectedNote.id ? "selected" : ""}`}
              key={note.id}
              title={noteTitle(note)}
            >
              <button className="tabSelectButton" onClick={() => selectNote(note.id)} type="button">
                <span>{noteTitle(note)}</span>
              </button>
              <button
                aria-label={`Close ${noteTitle(note)}`}
                className="iconButton nestedClose"
                onClick={() => closeNote(note.id)}
                type="button"
              >
                <X size={13} strokeWidth={2.4} />
              </button>
            </div>
          ))}
          <button className="newTabButton" onClick={createNewNote} type="button" aria-label="New Tab">
            <Plus size={16} strokeWidth={2.2} />
          </button>
        </div>
      </header>

      <section className="toolbar" aria-label="Editor toolbar">
        <button className="toolButton" onClick={() => runEditorCommand("bold")} type="button" title="Bold">
          <Bold size={16} />
        </button>
        <button className="toolButton" onClick={() => runEditorCommand("italic")} type="button" title="Italic">
          <Italic size={16} />
        </button>
        <div className="menuWrap">
          <button
            className={`toolButton ${activeMenu === "lists" ? "pressed" : ""}`}
            onClick={() => setActiveMenu(activeMenu === "lists" ? null : "lists")}
            type="button"
            title="Lists"
          >
            <List size={17} />
          </button>
          {activeMenu === "lists" ? (
            <div className="menuPanel">
              <button onClick={() => runListCommand("bullet")} type="button">
                <List size={15} />
                Bullet List
              </button>
              <button onClick={() => runListCommand("numbered")} type="button">
                <ListOrdered size={15} />
                Numbered List
              </button>
              <button onClick={() => runListCommand("checkbox")} type="button">
                <CheckSquare size={15} />
                Checkbox List
              </button>
            </div>
          ) : null}
        </div>

        <div className="toolbarDivider" />

        <button className="toolButton textTool" onClick={saveCurrentNote} type="button" title="Save">
          <Save size={16} />
          <span>Save</span>
        </button>
        <button className="toolButton textTool" onClick={saveCurrentNoteAs} type="button" title="Save As">
          <FilePlus size={16} />
          <span>Save As...</span>
        </button>

        <div className="toolbarSpacer" />

        <label className="selectControl">
          <TextQuote size={14} />
          <select value={state.settings.fontName} onChange={(event) => setSetting("fontName", event.target.value)}>
            {fontOptions.map((fontName) => (
              <option key={fontName} value={fontName}>
                {fontName}
              </option>
            ))}
          </select>
        </label>

        <label className="selectControl compact">
          <select
            value={state.settings.fontSize}
            onChange={(event) => setSetting("fontSize", Number(event.target.value))}
          >
            {fontSizes.map((fontSize) => (
              <option key={fontSize} value={fontSize}>
                {fontSize} pt
              </option>
            ))}
          </select>
        </label>

        <button
          className={`toolButton ${state.settings.wordWrap ? "pressed" : ""}`}
          onClick={() => setSetting("wordWrap", !state.settings.wordWrap)}
          type="button"
          title="Word Wrap"
        >
          <WrapText size={16} />
        </button>
        <button
          aria-pressed={state.settings.showLineNumbers}
          className={`toolButton ${state.settings.showLineNumbers ? "pressed" : ""}`}
          onClick={() => setSetting("showLineNumbers", !state.settings.showLineNumbers)}
          type="button"
          title="Line Numbers"
        >
          <ListOrdered size={16} />
        </button>
        <button className="toolButton" onClick={() => zoomBy(0.1)} type="button" title="Zoom In">
          <Plus size={15} />
        </button>
        <button className="toolButton" onClick={() => zoomBy(-0.1)} type="button" title="Zoom Out">
          <Minus size={15} />
        </button>
      </section>

      <Editor
        key={selectedNote.id}
        ref={editorRef}
        noteID={selectedNote.id}
        text={selectedNote.content}
        settings={state.settings}
        onChange={updateSelectedContent}
        onOptionScrollZoom={(delta) => zoomBy(delta > 0 ? 0.1 : -0.1)}
      />

      {saveToast ? <div className="saveToast">{saveToast}</div> : null}

      <footer className="statusBar">
        <span>{selectedNote.content.length} characters</span>
        <span>{lineCount(selectedNote.content)} lines</span>
        <span>{state.notes.length} tabs</span>
        <span className="sessionPath" title={storedSessionPath}>
          {storedSessionPath}
        </span>
        <button
          className="themeToggle"
          onClick={() => setSetting("theme", state.settings.theme === "dark" ? "light" : "dark")}
          type="button"
          title={state.settings.theme === "dark" ? "Switch to Light Theme" : "Switch to Dark Theme"}
        >
          {state.settings.theme === "dark" ? <Moon size={14} /> : <Sun size={14} />}
        </button>
        <span>{saveState}</span>
      </footer>
    </main>
  );
}

function suggestedFileName(note: Note): string {
  const savedFileName = note.filePath?.split(/[\\/]/).pop();
  if (savedFileName) {
    return savedFileName;
  }

  const sanitized = noteTitle(note)
    .replace(/[/:\\\n\r\t]/g, "-")
    .trim();

  return `${sanitized.length > 0 ? sanitized : "Untitled Note"}.txt`;
}

function ensureWritableExtension(path: string): string {
  return /\.(txt|md|markdown)$/i.test(path) ? path : `${path}.txt`;
}
