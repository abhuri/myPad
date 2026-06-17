import type { EditorSettings, Note, SessionState } from "./types";

export const defaultSettings: EditorSettings = {
  fontName: "Menlo",
  fontSize: 15,
  wordWrap: true,
  showLineNumbers: true,
  zoom: 1,
  theme: "light",
};

export function isoDate(date = new Date()): string {
  return date.toISOString().replace(/\.\d{3}Z$/, "Z");
}

export function createNote(content = ""): Note {
  const now = isoDate();

  return {
    id: crypto.randomUUID(),
    content,
    createdAt: now,
    updatedAt: now,
  };
}

export function noteTitle(note: Note): string {
  const firstLine = note.content
    .split(/\r?\n/)
    .find((line) => line.trim().length > 0)
    ?.trim() ?? "";

  if (!firstLine) {
    return "Untitled";
  }

  return firstLine.length <= 36 ? firstLine : `${firstLine.slice(0, 33)}...`;
}

export function lineCount(content: string): number {
  return content.length === 0 ? 1 : content.split(/\r\n|\r|\n/).length;
}

export function normalizeSession(input: unknown): SessionState {
  if (!input || typeof input !== "object") {
    return defaultSession();
  }

  const record = input as Partial<SessionState>;
  const notes = Array.isArray(record.notes)
    ? record.notes.map(normalizeNote).filter((note): note is Note => note !== null)
    : [];
  const normalizedNotes = notes.length > 0 ? notes : [createNote()];
  const selectedNoteID =
    typeof record.selectedNoteID === "string" &&
    normalizedNotes.some((note) => note.id === record.selectedNoteID)
      ? record.selectedNoteID
      : normalizedNotes[0]?.id;

  return {
    notes: normalizedNotes,
    selectedNoteID,
    settings: normalizeSettings(record.settings),
  };
}

export function defaultSession(): SessionState {
  const note = createNote();

  return {
    notes: [note],
    selectedNoteID: note.id,
    settings: { ...defaultSettings },
  };
}

export function stableSessionStringify(state: SessionState): string {
  return `${stableStringify(state, 0)}\n`;
}

function normalizeNote(input: unknown): Note | null {
  if (!input || typeof input !== "object") {
    return null;
  }

  const record = input as Partial<Note>;
  const now = isoDate();

  return {
    id: typeof record.id === "string" ? record.id : crypto.randomUUID(),
    content: typeof record.content === "string" ? record.content : "",
    filePath: typeof record.filePath === "string" && record.filePath.length > 0 ? record.filePath : undefined,
    createdAt: typeof record.createdAt === "string" ? record.createdAt : now,
    updatedAt: typeof record.updatedAt === "string" ? record.updatedAt : now,
  };
}

function normalizeSettings(input: unknown): EditorSettings {
  if (!input || typeof input !== "object") {
    return { ...defaultSettings };
  }

  const record = input as Partial<EditorSettings>;
  const fontSize = typeof record.fontSize === "number" ? record.fontSize : defaultSettings.fontSize;
  const zoom = typeof record.zoom === "number" ? record.zoom : defaultSettings.zoom;

  return {
    fontName: typeof record.fontName === "string" && record.fontName.length > 0 ? record.fontName : defaultSettings.fontName,
    fontSize: Math.max(9, Math.min(72, fontSize)),
    wordWrap: typeof record.wordWrap === "boolean" ? record.wordWrap : defaultSettings.wordWrap,
    showLineNumbers:
      typeof record.showLineNumbers === "boolean" ? record.showLineNumbers : defaultSettings.showLineNumbers,
    zoom: Math.max(0.5, Math.min(3, zoom)),
    theme: record.theme === "dark" ? "dark" : "light",
  };
}

function stableStringify(value: unknown, level: number): string {
  const spacing = "  ";
  const currentIndent = spacing.repeat(level);
  const nextIndent = spacing.repeat(level + 1);

  if (value === null || typeof value !== "object") {
    return JSON.stringify(value);
  }

  if (Array.isArray(value)) {
    if (value.length === 0) {
      return "[]";
    }

    const items = value.map((item) => `${nextIndent}${stableStringify(item, level + 1)}`);
    return `[\n${items.join(",\n")}\n${currentIndent}]`;
  }

  const entries = Object.entries(value as Record<string, unknown>)
    .filter(([, entryValue]) => entryValue !== undefined)
    .sort(([left], [right]) => left.localeCompare(right));

  if (entries.length === 0) {
    return "{}";
  }

  const properties = entries.map(
    ([key, entryValue]) => `${nextIndent}${JSON.stringify(key)} : ${stableStringify(entryValue, level + 1)}`
  );

  return `{\n${properties.join(",\n")}\n${currentIndent}}`;
}
