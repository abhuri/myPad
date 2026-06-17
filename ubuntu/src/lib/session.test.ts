import { describe, expect, it } from "vitest";
import { normalizeSession } from "./session";

describe("session settings", () => {
  it("keeps line numbers visible for older sessions", () => {
    const session = normalizeSession({
      notes: [{ id: "note-1", content: "", createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z" }],
      selectedNoteID: "note-1",
      settings: {
        fontName: "Menlo",
        fontSize: 15,
        wordWrap: true,
        zoom: 1,
        theme: "light",
      },
    });

    expect(session.settings.showLineNumbers).toBe(true);
  });

  it("preserves disabled line numbers", () => {
    const session = normalizeSession({
      notes: [{ id: "note-1", content: "", createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z" }],
      selectedNoteID: "note-1",
      settings: {
        fontName: "Menlo",
        fontSize: 15,
        wordWrap: true,
        showLineNumbers: false,
        zoom: 1,
        theme: "light",
      },
    });

    expect(session.settings.showLineNumbers).toBe(false);
  });
});
