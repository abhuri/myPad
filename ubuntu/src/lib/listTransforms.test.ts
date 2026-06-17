import { describe, expect, it } from "vitest";
import {
  adjustListIndent,
  applyListStyle,
  continueListAfterNewline,
  toggleCheckboxAt,
  toggleMarkdown,
} from "./listTransforms";

describe("editor transforms", () => {
  it("wraps and unwraps markdown delimiters", () => {
    const wrapped = toggleMarkdown("hello world", { from: 0, to: 5 }, "**");
    expect(wrapped.text).toBe("**hello** world");

    const unwrapped = toggleMarkdown(wrapped.text, { from: 2, to: 7 }, "**");
    expect(unwrapped.text).toBe("hello world");
  });

  it("applies list markers across selected lines", () => {
    const edit = applyListStyle("alpha\nbeta", { from: 0, to: 10 }, "checkbox");
    expect(edit.text).toBe("[ ] alpha\n[ ] beta");
  });

  it("continues a numbered list after enter", () => {
    const edit = continueListAfterNewline("1. alpha", 8);
    expect(edit.text).toBe("1. alpha\n2. ");
  });

  it("exits an empty top-level list item", () => {
    const edit = continueListAfterNewline("- ", 2);
    expect(edit.text).toBe("");
  });

  it("indents and outdents checkbox lines", () => {
    const indented = adjustListIndent("[ ] task", { from: 0, to: 0 }, true);
    expect(indented.text).toBe("    [ ] task");

    const outdented = adjustListIndent(indented.text, indented.selection, false);
    expect(outdented.text).toBe("[ ] task");
  });

  it("toggles checkbox markers", () => {
    const edit = toggleCheckboxAt("[ ] task", 1);
    expect(edit.text).toBe("[x] task");
  });
});
