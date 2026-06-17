import type { EditorListStyle } from "./types";

export const indentUnit = "    ";

export interface TextSelection {
  from: number;
  to: number;
}

export interface TextEdit {
  text: string;
  selection: TextSelection;
  handled: boolean;
}

interface LineInfo {
  from: number;
  to: number;
  text: string;
}

interface ListLine {
  style: EditorListStyle;
  text: string;
  indent: string;
  markerFrom: number;
  markerTo: number;
  bodyFrom: number;
  bodyTo: number;
  lineFrom: number;
  lineTo: number;
  body: string;
  numberPath: number[];
  isChecked: boolean;
}

export function toggleMarkdown(text: string, selection: TextSelection, delimiter: string): TextEdit {
  const from = clamp(selection.from, 0, text.length);
  const to = clamp(selection.to, from, text.length);
  const selectedText = text.slice(from, to);
  const before = text.slice(from - delimiter.length, from);
  const after = text.slice(to, to + delimiter.length);

  if (from >= delimiter.length && before === delimiter && after === delimiter && to > from) {
    const nextText = `${text.slice(0, from - delimiter.length)}${selectedText}${text.slice(to + delimiter.length)}`;
    const nextFrom = from - delimiter.length;
    return {
      text: nextText,
      selection: { from: nextFrom, to: nextFrom + selectedText.length },
      handled: true,
    };
  }

  const replacement = `${delimiter}${selectedText}${delimiter}`;
  const nextText = `${text.slice(0, from)}${replacement}${text.slice(to)}`;
  const cursorFrom = from + delimiter.length;

  return {
    text: nextText,
    selection: {
      from: cursorFrom,
      to: selectedText.length === 0 ? cursorFrom : cursorFrom + selectedText.length,
    },
    handled: true,
  };
}

export function applyListStyle(text: string, selection: TextSelection, style: EditorListStyle): TextEdit {
  const lines = selectedLines(text, selection);
  const replacement = lines
    .map((line, index) => lineWithListPrefix(line.text, style, index + 1))
    .join("\n");
  const nextText = replaceRange(text, lines[0].from, lines[lines.length - 1].to, replacement);

  return {
    text: nextText,
    selection: { from: lines[0].from, to: lines[0].from + replacement.length },
    handled: true,
  };
}

export function continueListAfterNewline(text: string, position: number): TextEdit {
  const line = lineAt(text, position);
  const listLine = parsedListLine(line);

  if (!listLine || position < listLine.markerTo) {
    return { text, selection: { from: position, to: position }, handled: false };
  }

  if (listLine.body.trim().length === 0 && position >= listLine.bodyFrom) {
    return finishEmptyListLine(text, listLine);
  }

  const insertion = `\n${listLine.indent}${nextMarkerAfter(listLine)}`;
  const nextText = replaceRange(text, position, position, insertion);
  const nextPosition = position + insertion.length;

  return {
    text: nextText,
    selection: { from: nextPosition, to: nextPosition },
    handled: true,
  };
}

export function adjustListIndent(text: string, selection: TextSelection, increasing: boolean): TextEdit {
  const lines = selectedLines(text, selection);
  let didChange = false;
  let cursorDelta = 0;
  const replacement = lines
    .map((line) => {
      const listLine = parsedListLine(line);

      if (!listLine) {
        return line.text;
      }

      const adjustedLine = increasing ? indentedLine(text, listLine) : outdentedLine(listLine);

      if (adjustedLine !== line.text) {
        didChange = true;
        if (line.from <= selection.from) {
          cursorDelta += adjustedLine.length - line.text.length;
        }
      }

      return adjustedLine;
    })
    .join("\n");

  if (!didChange) {
    return { text, selection, handled: false };
  }

  const nextText = replaceRange(text, lines[0].from, lines[lines.length - 1].to, replacement);
  const nextPosition = selection.from === selection.to
    ? clamp(selection.from + cursorDelta, lines[0].from, nextText.length)
    : lines[0].from;

  return {
    text: nextText,
    selection: {
      from: nextPosition,
      to: selection.from === selection.to ? nextPosition : lines[0].from + replacement.length,
    },
    handled: true,
  };
}

export function toggleCheckboxAt(text: string, position: number): TextEdit {
  const line = lineAt(text, position);
  const listLine = parsedListLine(line);

  if (!listLine || listLine.style !== "checkbox" || position < listLine.markerFrom || position > listLine.markerTo) {
    return { text, selection: { from: position, to: position }, handled: false };
  }

  const replacement = listLine.isChecked ? "[ ] " : "[x] ";
  const nextText = replaceRange(text, listLine.markerFrom, listLine.markerTo, replacement);
  const nextPosition = listLine.markerFrom + replacement.length;

  return {
    text: nextText,
    selection: { from: nextPosition, to: nextPosition },
    handled: true,
  };
}

function lineWithListPrefix(line: string, style: EditorListStyle, number: number): string {
  const [, indent = "", body = ""] = line.match(/^([ \t]*)(.*)$/) ?? [];
  return `${indent}${listMarker(style, number)}${stripExistingListMarker(body)}`;
}

function listMarker(style: EditorListStyle, number: number): string {
  if (style === "bullet") {
    return "- ";
  }

  if (style === "checkbox") {
    return "[ ] ";
  }

  return `${number}. `;
}

function stripExistingListMarker(body: string): string {
  const checkboxMarkers = ["[ ] ", "[] ", "[x] ", "[X] ", "- [ ] ", "- [x] ", "- [X] "];
  const plainMarkers = ["• ", "- ", "* ", "+ "];
  const checkbox = checkboxMarkers.find((marker) => body.startsWith(marker));
  const plain = plainMarkers.find((marker) => body.startsWith(marker));
  const numbered = numberedMarker(body);

  if (checkbox) {
    return body.slice(checkbox.length);
  }

  if (plain) {
    return body.slice(plain.length);
  }

  if (numbered) {
    return body.slice(numbered.length);
  }

  return body;
}

function finishEmptyListLine(text: string, listLine: ListLine): TextEdit {
  const promotedPrefix = promotedPrefixAfterEmptyLine(listLine);
  const replacement = promotedPrefix ?? "";
  const nextText = replaceRange(text, listLine.lineFrom, listLine.lineTo, replacement);
  const nextPosition = listLine.lineFrom + replacement.length;

  return {
    text: nextText,
    selection: { from: nextPosition, to: nextPosition },
    handled: true,
  };
}

function promotedPrefixAfterEmptyLine(listLine: ListLine): string | null {
  if (listLine.style === "numbered") {
    if (listLine.numberPath.length <= 1) {
      return null;
    }

    return numberedPrefix(incrementedNumberPath(listLine.numberPath.slice(0, -1)));
  }

  const depth = listDepth(listLine.indent);
  if (depth <= 0) {
    return null;
  }

  return `${indentForDepth(depth - 1)}${listMarker(listLine.style, 1)}`;
}

function indentedLine(text: string, listLine: ListLine): string {
  if (listLine.style !== "numbered") {
    return `${indentUnit}${listLine.text}`;
  }

  const prefix = numberedPrefix(demotedNumberPath(text, listLine));
  return `${prefix}${listLine.body}`;
}

function outdentedLine(listLine: ListLine): string {
  if (listLine.style === "numbered") {
    if (listLine.numberPath.length <= 1) {
      return listLine.text;
    }

    return `${numberedPrefix(listLine.numberPath.slice(0, -1))}${listLine.body}`;
  }

  const removable = removableIndentCount(listLine.text);
  return removable > 0 ? listLine.text.slice(removable) : listLine.text;
}

function parsedListLine(line: LineInfo): ListLine | null {
  const indent = line.text.match(/^[ \t]*/)?.[0] ?? "";
  const markerStart = line.from + indent.length;
  const body = line.text.slice(indent.length);
  const checkbox = checkboxMarker(body);

  if (checkbox) {
    return {
      style: "checkbox",
      indent,
      markerFrom: markerStart,
      markerTo: markerStart + checkbox.length,
      bodyFrom: markerStart + checkbox.length,
      bodyTo: line.to,
      lineFrom: line.from,
      lineTo: line.to,
      body: line.text.slice(indent.length + checkbox.length),
      numberPath: [1],
      isChecked: checkbox.isChecked,
      text: line.text,
    };
  }

  const bulletMarker = ["• ", "- ", "* ", "+ "].find((marker) => body.startsWith(marker));
  if (bulletMarker) {
    return {
      style: "bullet",
      indent,
      markerFrom: markerStart,
      markerTo: markerStart + bulletMarker.length,
      bodyFrom: markerStart + bulletMarker.length,
      bodyTo: line.to,
      lineFrom: line.from,
      lineTo: line.to,
      body: line.text.slice(indent.length + bulletMarker.length),
      numberPath: [1],
      isChecked: false,
      text: line.text,
    };
  }

  const numbered = numberedMarker(body);
  if (numbered) {
    return {
      style: "numbered",
      indent,
      markerFrom: markerStart,
      markerTo: markerStart + numbered.length,
      bodyFrom: markerStart + numbered.length,
      bodyTo: line.to,
      lineFrom: line.from,
      lineTo: line.to,
      body: line.text.slice(indent.length + numbered.length),
      numberPath: numbered.numberPath,
      isChecked: false,
      text: line.text,
    };
  }

  return null;
}

function checkboxMarker(body: string): { length: number; isChecked: boolean } | null {
  const markers: Array<[string, boolean]> = [
    ["[ ] ", false],
    ["[] ", false],
    ["[x] ", true],
    ["[X] ", true],
    ["- [ ] ", false],
    ["- [x] ", true],
    ["- [X] ", true],
  ];
  const marker = markers.find(([text]) => body.startsWith(text));

  return marker ? { length: marker[0].length, isChecked: marker[1] } : null;
}

function numberedMarker(body: string): { length: number; numberPath: number[] } | null {
  const match = body.match(/^(\d+(?:\.\d+)*[.)] )/);

  if (!match) {
    return null;
  }

  const marker = match[1];
  const numberText = marker.trim().replace(/[.)]$/, "");
  const numberPath = numberText.split(".").map(Number);

  if (numberPath.some((number) => !Number.isFinite(number))) {
    return null;
  }

  if (marker.includes(")") && numberPath.length > 1) {
    return null;
  }

  return { length: marker.length, numberPath };
}

function nextMarkerAfter(listLine: ListLine): string {
  if (listLine.style === "numbered") {
    return numberedMarkerText(incrementedNumberPath(listLine.numberPath));
  }

  return listMarker(listLine.style, 1);
}

function numberedMarkerText(numberPath: number[]): string {
  return `${numberPath.join(".")}. `;
}

function numberedPrefix(numberPath: number[]): string {
  return `${indentForDepth(Math.max(0, numberPath.length - 1))}${numberedMarkerText(numberPath)}`;
}

function incrementedNumberPath(numberPath: number[]): number[] {
  if (numberPath.length === 0) {
    return [1];
  }

  const next = [...numberPath];
  next[next.length - 1] += 1;
  return next;
}

function demotedNumberPath(text: string, listLine: ListLine): number[] {
  const previousSibling = previousNumberedSibling(text, listLine.lineFrom, listLine.numberPath);

  if (previousSibling) {
    return nextChildNumberPath(text, previousSibling.numberPath, listLine.lineFrom);
  }

  return [...listLine.numberPath, 1];
}

function nextChildNumberPath(text: string, parentPath: number[], lineFrom: number): number[] {
  let searchPosition = lineFrom;

  while (searchPosition > 0) {
    const previousLine = lineAt(text, searchPosition - 1);
    const previousListLine = parsedListLine(previousLine);

    if (previousListLine?.style === "numbered") {
      if (isImmediateChild(previousListLine.numberPath, parentPath)) {
        return incrementedNumberPath(previousListLine.numberPath);
      }

      if (sameNumberPath(previousListLine.numberPath, parentPath)) {
        break;
      }
    }

    if (previousLine.from === 0) {
      break;
    }

    searchPosition = previousLine.from;
  }

  return [...parentPath, 1];
}

function previousNumberedSibling(text: string, lineFrom: number, numberPath: number[]): ListLine | null {
  const currentNumber = numberPath[numberPath.length - 1];

  if (currentNumber === undefined || currentNumber <= 1) {
    return null;
  }

  let searchPosition = lineFrom;

  while (searchPosition > 0) {
    const previousLine = lineAt(text, searchPosition - 1);
    const previousListLine = parsedListLine(previousLine);

    if (
      previousListLine?.style === "numbered" &&
      isPreviousSibling(previousListLine.numberPath, numberPath)
    ) {
      return previousListLine;
    }

    if (previousLine.from === 0) {
      break;
    }

    searchPosition = previousLine.from;
  }

  return null;
}

function isPreviousSibling(candidatePath: number[], numberPath: number[]): boolean {
  const currentNumber = numberPath[numberPath.length - 1];
  const candidateNumber = candidatePath[candidatePath.length - 1];

  return (
    currentNumber !== undefined &&
    candidateNumber !== undefined &&
    currentNumber > 1 &&
    candidateNumber === currentNumber - 1 &&
    candidatePath.length === numberPath.length &&
    sameNumberPath(candidatePath.slice(0, -1), numberPath.slice(0, -1))
  );
}

function isImmediateChild(candidatePath: number[], parentPath: number[]): boolean {
  return (
    candidatePath.length === parentPath.length + 1 &&
    sameNumberPath(candidatePath.slice(0, parentPath.length), parentPath)
  );
}

function sameNumberPath(left: number[], right: number[]): boolean {
  return left.length === right.length && left.every((number, index) => number === right[index]);
}

function indentForDepth(depth: number): string {
  return indentUnit.repeat(Math.max(0, depth));
}

function listDepth(indent: string): number {
  let depth = 0;
  let spaces = 0;

  for (const character of indent) {
    if (character === "\t") {
      depth += 1;
      spaces = 0;
    } else if (character === " ") {
      spaces += 1;
      if (spaces === indentUnit.length) {
        depth += 1;
        spaces = 0;
      }
    }
  }

  return spaces > 0 ? depth + 1 : depth;
}

function removableIndentCount(line: string): number {
  if (line.startsWith("\t")) {
    return 1;
  }

  let count = 0;
  for (const character of line) {
    if (character !== " " || count >= indentUnit.length) {
      break;
    }

    count += 1;
  }

  return count;
}

function selectedLines(text: string, selection: TextSelection): LineInfo[] {
  const from = clamp(selection.from, 0, text.length);
  const to = clamp(selection.to, from, text.length);
  const first = lineAt(text, from);
  const last = lineAt(text, to > from && text[to - 1] === "\n" ? to - 1 : to);
  const lines: LineInfo[] = [];
  let cursor = first.from;

  while (cursor <= last.from) {
    const line = lineAt(text, cursor);
    lines.push(line);

    if (line.to >= text.length) {
      break;
    }

    cursor = line.to + 1;
  }

  return lines.length > 0 ? lines : [first];
}

function lineAt(text: string, position: number): LineInfo {
  const pos = clamp(position, 0, text.length);
  const from = text.lastIndexOf("\n", Math.max(0, pos - 1)) + 1;
  const nextBreak = text.indexOf("\n", pos);
  const to = nextBreak === -1 ? text.length : nextBreak;

  return {
    from,
    to,
    text: text.slice(from, to),
  };
}

function replaceRange(text: string, from: number, to: number, replacement: string): string {
  return `${text.slice(0, from)}${replacement}${text.slice(to)}`;
}

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}
