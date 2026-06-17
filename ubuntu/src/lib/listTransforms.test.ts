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

  it("demotes numbered items under the previous sibling", () => {
    const text = "1. alpha\n2. beta";
    const edit = adjustListIndent(text, { from: text.length, to: text.length }, true);

    expect(edit.text).toBe("1. alpha\n    1.1. beta");
  });

  it("continues and promotes numbered subitems from empty lines", () => {
    const continued = continueListAfterNewline("1. alpha\n    1.1. beta", 23);
    expect(continued.text).toBe("1. alpha\n    1.1. beta\n    1.2. ");

    const promoted = continueListAfterNewline(continued.text, continued.text.length);
    expect(promoted.text).toBe("1. alpha\n    1.1. beta\n2. ");

    const exited = continueListAfterNewline(promoted.text, promoted.text.length);
    expect(exited.text).toBe("1. alpha\n    1.1. beta\n");
  });

  it("exits an empty top-level list item", () => {
    const edit = continueListAfterNewline("- ", 2);
    expect(edit.text).toBe("");
  });

  it("promotes nested bullet list items from empty lines", () => {
    const text = "- parent\n    - ";
    const promoted = continueListAfterNewline(text, text.length);
    expect(promoted.text).toBe("- parent\n- ");

    const exited = continueListAfterNewline(promoted.text, promoted.text.length);
    expect(exited.text).toBe("- parent\n");
  });

  it("indents and outdents checkbox lines", () => {
    const indented = adjustListIndent("[ ] task", { from: 0, to: 0 }, true);
    expect(indented.text).toBe("    [ ] task");

    const outdented = adjustListIndent(indented.text, indented.selection, false);
    expect(outdented.text).toBe("[ ] task");
  });

  it("promotes nested checkbox list items from empty lines", () => {
    const promoted = continueListAfterNewline("[ ] parent\n    [ ] ", 19);
    expect(promoted.text).toBe("[ ] parent\n[ ] ");

    const exited = continueListAfterNewline(promoted.text, promoted.text.length);
    expect(exited.text).toBe("[ ] parent\n");
  });

  it("toggles checkbox markers", () => {
    const edit = toggleCheckboxAt("[ ] task", 1);
    expect(edit.text).toBe("[x] task");
  });
});
