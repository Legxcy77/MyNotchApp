# คลังแสง 12 โปรเจกต์ Open-Source บน GitHub สำหรับอัปเกรด `MyNotchApp`
เอกสารนี้รวบรวมโปรเจกต์ Open-Source ระดับท็อปบน GitHub ที่ตรงกับฟีเจอร์ของ `MyNotchApp` และ `Canopy` แบบจุดต่อจุด (หลายตัวคือต้นฉบับที่ `Canopy` เอาไปใช้จริงใน `.app` ของเขา!) เพื่อให้เราดึงแนวคิด/โมดูลมาต่อยอดได้ทันทีโดยไม่ต้องเริ่มศูนย์

---

## 1. [`Lakr233/SkyLightWindow`](https://github.com/Lakr233/SkyLightWindow) — ตัววาง UI ทับหน้า Lock Screen จริงของ Mac
- **สิ่งที่ทำ:** ไลบรารี Swift ที่หุ้ม `SkyLight.framework` (`SLSSpaceCreate`, `SLSSpaceSetAbsoluteLevel`, `SLSShowSpaces`, `SLSSpaceAddWindowsAndRemoveFromSpaces`) พร้อมตัวช่วย `.moveToSky()` สำหรับเอา View ของ SwiftUI/AppKit ไปลอยเหนือหน้า Lock Screen จริงของ macOS (`loginwindow`)
- **เอามาทำอะไรในของเรา:**
  - ใช้เป็นต้นแบบ `SkyLightLockSpaceBridge.swift` ของเรา เพื่อเอาเฉพาะ **การ์ดเพลง + ปกใหญ่ + เนื้อเพลง + ปุ่ม Face ID** ไปลอยบนหน้าล็อกจริงของ Mac (`Ctrl+Cmd+Q`) โดยไม่ต้องทำหน้าดำบังทั้งจอ และปล่อยให้ Touch ID / ช่องรหัสผ่านจริงของ Mac ข้างล่างทำงานตามปกติ 100%

---

## 2. [`TheBoredTeam/boring.notch`](https://github.com/TheBoredTeam/boring.notch) — แอป Notch Open-Source ที่ใหญ่ที่สุดบน macOS
- **สิ่งที่ทำ:** เปลี่ยน Notch ของ MacBook เป็น Dynamic Island แบบครบวงจรด้วย Swift/SwiftUI (Music Player + Visualizer, Lock Screen Widget, AirPods Battery, Custom Volume/Brightness HUD, File Shelf + AirDrop, Calendar)
- **เอามาทำอะไรในของเรา:**
  - ดูวิธีทำ **HUD แทนที่แถบเพิ่ม/ลดเสียงและแสงของ macOS** (ปิด `OSDUIHelper` ชั่วคราวแล้วแสดงใน Notch แทน)
  - ดูวิธีทำ **AirPods подключение + แบตเตอรี่ซ้าย/ขวา/เคส**
  - ดูการทำ **Gesture ปัดเปิด/ปิด Notch ด้วย Trackpad two-finger swipe**

---

## 3. [`Ebullioscopic/Atoll`](https://github.com/Ebullioscopic/Atoll) — Dynamic Island + Lock Screen Widgets + Live Activities
- **สิ่งที่ทำ:** แอป Dynamic Island บน macOS ที่เน้นความลื่นไหลของแอนิเมชัน มีระบบ **Lock Screen Widgets**, **Live Activities** และ SDK (`atoll-js`) ให้แอปอื่นส่งสถานะขึ้น Notch ได้
- **เอามาทำอะไรในของเรา:**
  - นำแนวคิดการจัดวาง **Lock Screen Widget & Media Card** และระบบ переход (transition) ระหว่างโหมดย่อ ↔ โหมดเต็มมาปรับใช้

---

## 4. [`ungive/mediaremote-adapter`](https://github.com/ungive/mediaremote-adapter) — ตัวดึง Now Playing ที่ `Canopy` ใช้จริง!
- **สิ่งที่ทำ:** ตอนที่เราแกะ `Canopy.app` เราเจอ `MediaRemoteAdapter.framework` และ `mediaremote-adapter.pl` อยู่ข้างใน — ซึ่งมาจากโปรเจกต์ Open-Source ตัวนี้! มันช่วยแก้ปัญหาที่ macOS 15.4+ / macOS 26 บล็อก `MediaRemote.framework` จากแอปทั่วไป
- **เอามาทำอะไรในของเรา:**
  - ใช้เทคนิค XPC Helper (`com.apple.controlcenter.*`) หรือ `mediaremote-adapter` เพื่อให้ดึงเพลง ตำแหน่งเวลา และกดข้ามเพลง/เลื่อนแถบเวลา (Seek) ได้กับทุกแอป 100%

---

## 5. [`opencv/opencv_zoo` — `face_recognition_sface`](https://github.com/opencv/opencv_zoo/tree/main/models/face_recognition_sface) — โมเดลสแกนหน้าที่ `Canopy` ใช้จริง!
- **สิ่งที่ทำ:** โมเดล AI สแกนใบหน้า `SFace` (Apache-2.0 License) ขนาดเบาพิเศษ (~60 KB หลังแปลงเป็น CoreML `SFace.mlmodelc`) รับภาพใบหน้า `112×112` ที่จัดแนวตามจุดตา/จมูก/ปาก แล้วคืนค่าเวกเตอร์ `128 มิติ`
- **เอามาทำอะไรในของเรา:**
  - นำโมเดล `SFace` มาใส่ใน `FaceAuthService` ของเราแทน `VNGenerateImageFeaturePrintRequest` เพื่อให้จำหน้าเจ้าของเครื่องได้แม่นยำและเร็วระดับมิลลิวินาที แม้แสงเปลี่ยน

---

## 6. [`ddddxxx/LyricsX`](https://github.com/ddddxxx/LyricsX) & [`WuBarlynn/LyricsX_2.0`](https://github.com/WuBarlynn/LyricsX_2.0) — สุดยอดระบบค้นหาเนื้อเพลงหลายแหล่ง (Swift)
- **สิ่งที่ทำ:** แอปและไลบรารีเนื้อเพลงภาษา Swift บน macOS ที่ดึงเนื้อเพลงได้จากหลายแหล่งพร้อมกัน: **NetEase Cloud Music (เพลงจีน/เอเชียเยอะมาก)**, **QQ Music**, **Kugou**, **Musixmatch**, และ **LRCLib** พร้อมรองรับเนื้อเพลงแบบไล่ทีละคำ (Karaoke Word-by-Word / Syllable Timing)
- **เอามาทำอะไรในของเรา:**
  - ดึงโค้ดส่วน Provider ของ **QQ Music / NetEase / Kugou** มาต่อเป็น Fallback ถัดจาก LRCLib และ Safari YT Music! คราวนี้เพลงจีน เพลงแร็ป เวอร์ชันคัฟเวอร์ หรือเพลงเอเชียที่ไม่มีใน LRCLib จะขึ้นเนื้อแบบ Synced แทบทุกเพลง!

---

## 7. [`Lakr233/NotchDrop`](https://github.com/Lakr233/NotchDrop) — ต้นตำรับถาดพักไฟล์ + ส่ง AirDrop จาก Notch
- **สิ่งที่ทำ:** ลากไฟล์ไปวางที่ Notch เพื่อพักไฟล์ไว้ หรือลากไปปล่อยใส่ปุ่ม **AirDrop** เพื่อส่งเข้า iPhone/iPad ทันทีด้วย `NSSharingService(named: .sendViaAirDrop)`
- **เอามาทำอะไรในของเรา:**
  - เพิ่มปุ่ม **One-Click AirDrop** ในถาดพักไฟล์ (`FileTray`) ของเรา ลากไฟล์มาใส่ Notch แล้วกดส่ง AirDrop ได้ทันที

---

## 8. [`MrKai77/DynamicNotchKit`](https://github.com/MrKai77/DynamicNotchKit) — รูปทรงโค้งรับมุม Notch (Smooth Bezier Ears)
- **สิ่งที่ทำ:** Swift Package จากผู้สร้างแอปจัดหน้าต่างชื่อดัง *Loop* สำหรับวาดเส้นโค้งส่วนหัวของ Notch (Top-left / Top-right concave ears) ให้แนบสนิทกับขอบจอ MacBook เหมือนเป็นชิ้นเดียวกับฮาร์ดแวร์
- **เอามาทำอะไรในของเรา:**
  - นำสมการเส้นโค้ง Bezier ของมุมบน Notch มาใส่ใน `IslandLayout` เพื่อให้ขอบบนโค้งรับกับรอยบากกล้องแบบไร้รอยต่อ

---

## 9. [`NUIKit/CGSInternal`](https://github.com/NUIKit/CGSInternal) — คัมภีร์ Header ของ `SkyLight` / `CoreGraphicsServices`
- **สิ่งที่ทำ:** รวบรวม Header ลับของ macOS WindowServer (`CGSSpace.h`, `CGSWindow.h`, `CGSSession.h`, `CGSConnection.h`)
- **เอามาทำอะไรในของเรา:**
  - ใช้อ้างอิง Signature ของฟังก์ชัน `SLSSpaceCreate`, `SLSSpaceSetAbsoluteLevel`, `CGSSessionScreenIsLocked` และ `CGShieldingWindowLevel` ได้อย่างถูกต้อง 100%

---

## 10. [`AlexPerathoner/SlimHUD`](https://github.com/AlexPerathoner/SlimHUD) — แทนที่ HUD เสียง/แสงดั้งเดิมของ macOS
- **สิ่งที่ทำ:** ดักจับการกดปุ่มเพิ่ม/ลดเสียง, ความสว่างจอ, และไฟคีย์บอร์ด พร้อมซ่อนกรอบสี่เหลี่ยมเทาๆ ของระบบ (`OSDUIHelper`) เพื่อแสดงกราฟิกของเราเองแทน
- **เอามาทำอะไรในของเรา:**
  - ใช้ทำ Roadmap ข้อ **B1 (Volume/Brightness HUD in the island)** เวลากดปุ่มเพิ่ม/ลดเสียงหรือแสงบนคีย์บอร์ด ให้กางออกจาก Notch สวยๆ แทนกรอบสี่เหลี่ยมเดิมของ Mac!

---

## 11. [`exelban/stats`](https://github.com/exelban/stats) — ระบบอ่านค่าฮาร์ดแวร์ & แบตเตอรี่ AirPods/Bluetooth เชิงลึก
- **สิ่งที่ทำ:** แอปมอนิเตอร์เครื่องภาษา Swift ที่อ่านได้ตั้งแต่ อุณหภูมิ CPU/GPU, รอบพัดลม, กำลังไฟ (Watts), ไปจนถึง **เปอร์เซ็นต์แบตเตอรี่ของ AirPods (ซ้าย / ขวา / เคส)** ผ่าน `IOKit` และ `IOBluetooth`
- **เอามาทำอะไรในของเรา:**
  - ดึงโมดูลอ่านค่าแบตเตอรี่ AirPods มาทำ **AirPods Connect Popup** ใน Notch (พอเปิดฝาเคส AirPods ปุ๊บ Notch กางออกโชว์แบตซ้าย/ขวา/เคส เหมือน iPhone และ Canopy!)

---

## 12. [`FuzzyIdeas/MusicDecoy`](https://github.com/FuzzyIdeas/MusicDecoy) — กันปุ่ม Play บนคีย์บอร์ดไปเผลอเปิดแอป Apple Music
- **สิ่งที่ทำ:** แก้ปัญหายอดฮิตของคนฟัง YouTube Music / Spotify บน Mac ที่พอกดปุ่ม Play บนคีย์บอร์ดแล้วแอป Apple Music ชอบเด้งขึ้นมาเอง

---

## สรุปลำดับตัวที่คุ้มค่าที่สุดที่จะดึงมาใส่ `MyNotchApp` ก่อน
1. **อันดับ 1 (`Lakr233/SkyLightWindow` + `NUIKit/CGSInternal`):** เอาการ์ดเพลง 3 โหมด + เนื้อเพลง + ปุ่ม Face ID ของเรา ไปลอยทับ **หน้า Lock Screen จริงของ macOS (`Ctrl+Cmd+Q`)** — ปลอดภัย 100% ไม่ค้าง และใช้ Touch ID จริงของเครื่องได้เลย!
2. **อันดับ 2 (`LyricsX` Multi-Source Providers):** เพิ่มตัวดึงเนื้อเพลงจาก **NetEase / QQ Music** ต่อจาก LRCLib เพื่อให้เพลงจีน/ไทย/เกาหลี/ญี่ปุ่นที่มีไทม์ไลน์ขึ้นครบแทบทุกเพลง
3. **อันดับ 3 (`boring.notch` + `SlimHUD` + `stats`):** ทำ Volume/Brightness HUD กางออกจาก Notch + แอนิเมชันโชว์แบตเตอรี่ AirPods ตอนเชื่อมต่อ

