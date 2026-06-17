# วิธีเอา myPad ขึ้น GitHub แบบ Public

เอกสารนี้สำหรับคนที่เพิ่งเริ่มใช้ GitHub และต้องการเก็บ source code ของ
myPad ไว้โหลดกลับมาใช้หรือพัฒนาต่อในอนาคต

## คำศัพท์สั้น ๆ

- Git คือระบบจดประวัติการเปลี่ยนแปลงของไฟล์ในโปรเจกต์
- Commit คือจุดเซฟหนึ่งจุดของโปรเจกต์
- GitHub คือเว็บที่เก็บ repo ออนไลน์
- Repository หรือ repo คือกล่องเก็บโปรเจกต์หนึ่งกล่อง
- Push คือส่ง commit จากเครื่องเราไป GitHub
- Pull คือดึง code จาก GitHub กลับมาเครื่องเรา

## ขั้นตอนบนเว็บ GitHub

1. สมัครหรือเข้าสู่ระบบที่ `https://github.com`
2. กดปุ่ม `+` มุมขวาบน แล้วเลือก `New repository`
3. ตั้งชื่อ repo เป็น `myPad`
4. เลือก `Public`
5. ไม่ต้องติ๊ก `Add a README file` เพราะโปรเจกต์นี้มี README แล้ว
6. กด `Create repository`

หลังสร้าง repo แล้ว GitHub จะแสดง URL ประมาณนี้

```text
https://github.com/YOUR_USERNAME/myPad.git
```

ให้แทน `YOUR_USERNAME` ด้วย username ของบัญชี GitHub จริง

## ขั้นตอนบนเครื่อง

จากโฟลเดอร์โปรเจกต์นี้ ให้รันคำสั่งต่อไปนี้

```bash
git remote add origin https://github.com/YOUR_USERNAME/myPad.git
git push -u origin main
```

ถ้า GitHub ขอ login ให้ทำตามขั้นตอนที่หน้า terminal หรือ browser แสดง

## หลัง Push สำเร็จ

เปิดหน้า repo บน GitHub แล้วจะเห็นไฟล์สำคัญ เช่น

- `README.md`
- `Package.swift`
- `Sources`
- `Resources`
- `script`
- `LICENSE`

GitHub Actions จะรัน `swift build` อัตโนมัติ และจะแสดงสถานะ build บนหน้า repo

## การอัปเดต Code รอบต่อไป

หลังแก้ code ในอนาคต ให้ใช้ลำดับนี้

```bash
git status
git add .
git commit -m "Describe the change"
git push
```

## การโหลดกลับมาใช้ในเครื่องใหม่

ใช้คำสั่งนี้

```bash
git clone https://github.com/YOUR_USERNAME/myPad.git
cd myPad
/bin/bash ./script/install_app.sh
```

หลังติดตั้งแล้ว ให้หา `myPad` ใน Spotlight
