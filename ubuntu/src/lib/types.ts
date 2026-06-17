export type EditorTheme = "light" | "dark";

export type EditorListStyle = "bullet" | "numbered" | "checkbox";

export interface Note {
  id: string;
  content: string;
  filePath?: string;
  createdAt: string;
  updatedAt: string;
}

export interface EditorSettings {
  fontName: string;
  fontSize: number;
  wordWrap: boolean;
  showLineNumbers: boolean;
  zoom: number;
  theme: EditorTheme;
}

export interface SessionState {
  notes: Note[];
  selectedNoteID?: string;
  settings: EditorSettings;
}

export type SaveState = "Saved" | "Saving..." | "Saved to file" | "Save failed" | "File save failed";
