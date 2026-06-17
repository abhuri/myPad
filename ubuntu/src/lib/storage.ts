import { invoke, isTauri } from "@tauri-apps/api/core";
import type { SessionState } from "./types";
import { defaultSession, normalizeSession, stableSessionStringify } from "./session";

const browserStorageKey = "mypad.session";

export async function loadSession(): Promise<SessionState> {
  if (isTauri()) {
    const raw = await invoke<string | null>("load_session");
    return raw ? normalizeSession(JSON.parse(raw)) : defaultSession();
  }

  const raw = window.localStorage.getItem(browserStorageKey);
  return raw ? normalizeSession(JSON.parse(raw)) : defaultSession();
}

export async function saveSession(state: SessionState): Promise<void> {
  const stateJson = stableSessionStringify(state);

  if (isTauri()) {
    await invoke("save_session", { stateJson });
    return;
  }

  window.localStorage.setItem(browserStorageKey, stateJson);
}

export async function sessionPath(): Promise<string> {
  if (isTauri()) {
    return invoke<string>("session_path");
  }

  return "browser localStorage";
}

export async function saveNoteToPath(path: string, content: string): Promise<void> {
  if (isTauri()) {
    await invoke("save_note_file", { path, content });
    return;
  }

  downloadTextFile(path, content);
}

export async function chooseSavePath(defaultName: string, extension: "txt" | "md"): Promise<string | null> {
  if (isTauri()) {
    const { save } = await import("@tauri-apps/plugin-dialog");
    return save({
      title: "Save Note",
      defaultPath: defaultName,
      filters: [
        extension === "md"
          ? { name: "Markdown", extensions: ["md", "markdown"] }
          : { name: "Plain Text", extensions: ["txt"] },
      ],
    });
  }

  return defaultName;
}

export async function closeAppWindow(): Promise<void> {
  if (!isTauri()) {
    return;
  }

  const { getCurrentWindow } = await import("@tauri-apps/api/window");
  await getCurrentWindow().close();
}

function downloadTextFile(path: string, content: string): void {
  const fileName = path.split(/[\\/]/).pop() || "Untitled Note.txt";
  const url = URL.createObjectURL(new Blob([content], { type: "text/plain;charset=utf-8" }));
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = fileName;
  anchor.click();
  URL.revokeObjectURL(url);
}
