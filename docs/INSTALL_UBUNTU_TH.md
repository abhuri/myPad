# ติดตั้ง myPad บน Ubuntu

ตอนนี้ Ubuntu build ของ myPad ใช้วิธีแจกผ่าน GitHub Release ค่ะ

## วิธีที่แนะนำ: ติดตั้งจาก `.deb`

เปิดหน้า release ของ repo:

```text
https://github.com/abhuri/myPad/releases
```

เลือก release ที่ขึ้นต้นด้วย `ubuntu-v` แล้วดาวน์โหลดไฟล์ `.deb`

ติดตั้งด้วยคำสั่ง:

```bash
sudo apt install ./myPad-ubuntu-*.deb
```

ถ้าใช้ `dpkg` แล้วเจอ dependency ขาด ให้รัน:

```bash
sudo apt --fix-broken install
```

## วิธี portable: ใช้ AppImage

ดาวน์โหลดไฟล์ `.AppImage` จาก release เดียวกัน แล้วรัน:

```bash
chmod +x ./myPad-ubuntu-*.AppImage
./myPad-ubuntu-*.AppImage
```

บน Ubuntu บางเวอร์ชัน AppImage อาจต้องมี FUSE:

```bash
sudo apt update
sudo apt install libfuse2
```

## ดาวน์โหลดผ่าน terminal ด้วย GitHub CLI

ถ้าติดตั้ง `gh` ไว้แล้ว:

```bash
gh release download ubuntu-v0.1.0 \
  --repo abhuri/myPad \
  --pattern "*.deb"

sudo apt install ./myPad-ubuntu-*.deb
```

สำหรับ AppImage:

```bash
gh release download ubuntu-v0.1.0 \
  --repo abhuri/myPad \
  --pattern "*.AppImage"

chmod +x ./myPad-ubuntu-*.AppImage
./myPad-ubuntu-*.AppImage
```

## Build เองจาก source

ติดตั้ง prerequisites:

```bash
sudo apt update
sudo apt install libwebkit2gtk-4.1-dev \
  build-essential \
  curl \
  wget \
  file \
  libxdo-dev \
  libssl-dev \
  libayatana-appindicator3-dev \
  librsvg2-dev
```

ติดตั้ง Rust/Cargo:

```bash
curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh
. "$HOME/.cargo/env"
```

Clone และรัน:

```bash
git clone https://github.com/abhuri/myPad.git
cd myPad/ubuntu
npm install
npm run tauri:dev
```

Build package เอง:

```bash
npm run tauri:build
```

ไฟล์ package จะอยู่ใต้:

```text
ubuntu/src-tauri/target/release/bundle/
```

## สำหรับ maintainer: สร้าง release ใหม่

GitHub Actions workflow ชื่อ `Build Ubuntu Tauri` จะ build `.deb` และ AppImage ให้อัตโนมัติค่ะ

วิธี trigger ด้วย tag:

```bash
git tag ubuntu-v0.1.0
git push origin ubuntu-v0.1.0
```

หรือไปที่ GitHub > Actions > Build Ubuntu Tauri > Run workflow
