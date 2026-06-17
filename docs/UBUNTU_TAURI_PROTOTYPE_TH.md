# myPad Ubuntu/Tauri Prototype

เอกสารนี้อธิบาย feasibility prototype สำหรับพอร์ต myPad ไป Ubuntu โดยไม่แตะโค้ด macOS เดิม

## โครงสร้าง

- `ubuntu/` คือแอพ prototype ฝั่ง Ubuntu
- `ubuntu/src/` คือ React + CodeMirror frontend
- `ubuntu/src-tauri/` คือ Tauri shell และ Rust commands สำหรับ session/file persistence
- macOS app เดิมยังอยู่ที่ `Sources/myPad`

## Core ที่ตั้งใจให้ใช้ร่วมกัน

- Session JSON ยังใช้ schema เดิม: `notes`, `selectedNoteID`, `settings`
- Note ยังมี `id`, `content`, `filePath`, `createdAt`, `updatedAt`
- Settings ยังมี `fontName`, `fontSize`, `wordWrap`, `zoom`, `theme`
- วันที่ถูกเขียนเป็น ISO8601 แบบไม่มี fractional seconds เพื่อให้ macOS Swift decoder อ่านง่าย

## Ubuntu session path

Tauri prototype เก็บ session ที่:

```text
$XDG_DATA_HOME/myPad/session.json
```

ถ้าไม่มี `XDG_DATA_HOME` จะ fallback เป็น:

```text
~/.local/share/myPad/session.json
```

## รัน frontend prototype บนเครื่อง dev

```bash
cd ubuntu
npm install
npm run dev
```

เปิด URL ที่ Vite แสดง เช่น:

```text
http://localhost:5173
```

โหมด browser จะใช้ `localStorage` แทน Tauri session file เพื่อให้ทดสอบ UI ได้โดยไม่ต้องมี Rust

## รัน Tauri บน Ubuntu

ต้องติดตั้ง prerequisites ของ Tauri ก่อน เช่น Rust, Cargo และ Linux WebKit/GTK packages ตามเอกสาร Tauri

จากนั้นรัน:

```bash
cd ubuntu
npm install
npm run tauri:dev
```

## Build เป็น package

หลังติดตั้ง prerequisites แล้ว:

```bash
cd ubuntu
npm run tauri:build
```

config ตอนนี้ตั้ง target ไว้ที่ `.deb` และ AppImage

## MVP acceptance criteria

- เปิดแอพแล้วมี note อย่างน้อย 1 tab
- สร้าง สลับ และปิด tabs ได้
- พิมพ์ plain text ต่อเนื่องใน editor ได้
- Autosave และ restore session ได้
- รองรับ bold/italic Markdown helpers
- รองรับ bullet, numbered และ checkbox list ขั้นต้น
- กด Enter เพื่อ continue/exit list ได้
- กด Tab และ Shift+Tab เพื่อ indent/outdent list ได้
- คลิก marker checkbox เพื่อ toggle ได้
- ปรับ theme, word wrap, font size และ zoom ได้
- Save note เป็น `.txt` หรือ `.md` ได้ผ่าน Tauri save dialog

## ข้อจำกัดของ prototype รอบนี้

- ยังไม่ได้ verify Tauri desktop build เพราะเครื่อง dev นี้ยังไม่มี `cargo`
- Numbered-list hierarchy ใน prototype ยังเป็น MVP และควรเทียบละเอียดกับ macOS ก่อน release
- ยังไม่มี native menu bar แบบ macOS
- ยังไม่มี test บน Ubuntu จริงและยังไม่ได้สร้าง `.deb`/AppImage จริง
