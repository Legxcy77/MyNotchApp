# MyNotchApp — Master Development Plan
## Product Vision, Engineering Strategy, UX Standards, Quality Assurance & AI Execution Protocol

**Document Type:** Master Product & Engineering Specification  
**Project:** MyNotchApp  
**Platform:** macOS — Apple Silicon first  
**Primary Language:** Swift 6  
**UI Framework:** AppKit + SwiftUI  
**Integration:** NotchKit  
**Document Status:** Proposed Master Plan — Requires Repository Audit Before Execution  
**Intended Audience:** Project Owner, AI Coding Agents, Developers, Testers, Future Contributors

---

# 0. คำสั่งสำคัญสำหรับ AI ที่ได้รับเอกสารนี้

เอกสารนี้เป็นแนวทางหลักสำหรับการวิเคราะห์ วางแผน และพัฒนา MyNotchApp

**คุณไม่ได้รับมอบหมายให้สร้างฟีเจอร์ให้ได้มากที่สุด แต่ได้รับมอบหมายให้ช่วยสร้างผลิตภัณฑ์ที่แก้ปัญหาจริง ใช้งานได้จริง เข้าใจง่าย เชื่อถือได้ และมีคุณภาพเพียงพอสำหรับให้ Developer คนอื่นนำไปใช้งาน**

ก่อนดำเนินการใด ๆ ต้องเข้าใจบริบทของโปรเจกต์ ตรวจสอบโค้ดจริง และประเมินความเสี่ยงก่อนเสมอ

## 0.1 Non-Negotiable Rules

กฎต่อไปนี้เป็นข้อบังคับ ไม่ใช่คำแนะนำ

1. ห้ามสมมติว่าโค้ด ฟีเจอร์ หรือระบบใดมีอยู่จริง หากยังไม่ได้ตรวจสอบ Repository
2. ห้ามสร้างระบบใหม่ทับระบบเดิมเพียงเพราะไม่เข้าใจ Architecture ปัจจุบัน
3. ห้ามเปลี่ยน Architecture โดยไม่มีเหตุผลทางเทคนิคที่อธิบายได้
4. ห้ามสร้าง UI เพื่อให้ดูสวยหรือดูทันสมัย โดยไม่พิจารณาประโยชน์ในการใช้งาน
5. ห้ามใช้คำศัพท์ทางเทคนิคที่ Developer มือใหม่หรือผู้ใช้ทั่วไปไม่สามารถเข้าใจได้โดยไม่จำเป็น
6. ห้ามใช้ AI เป็นข้ออ้างในการเพิ่มความซับซ้อนให้ผลิตภัณฑ์
7. ห้ามสร้าง Notification ที่ไม่มีความสำคัญหรือไม่มีทางเลือกให้ผู้ใช้ดำเนินการ
8. ห้ามสร้างข้อมูลจำลองแล้วนำเสนอเหมือนเป็นข้อมูลจริง
9. ห้ามรายงานว่า Build, Test, Integration หรือ Feature ผ่าน หากยังไม่ได้ดำเนินการตรวจสอบจริง
10. ห้ามลดความเข้มงวดของ Test เพื่อทำให้ผลลัพธ์เป็น Passed
11. ห้ามแก้ Test ให้ผ่านด้วยการลบ Assertion, ปิด Test หรือเปลี่ยน Expected Result โดยไม่มีหลักฐานรองรับ
12. ห้ามกลืน Error หรือซ่อน Failure เพื่อทำให้ UI ดูเหมือนทำงานปกติ
13. ห้ามใช้ `try?`, fallback หรือ default value เพื่อปกปิดข้อผิดพลาดโดยไม่พิจารณาความหมายของ Error
14. ห้ามแก้ปัญหาด้วยการเพิ่ม Delay, Sleep หรือ Polling โดยไม่เข้าใจต้นเหตุ
15. ห้ามทำงานต่อเมื่อยังไม่เข้าใจผลกระทบของการเปลี่ยนแปลงในระดับที่ยอมรับได้
16. ห้ามแก้ไขไฟล์จำนวนมากในครั้งเดียวโดยไม่แบ่งขอบเขตและตรวจสอบผลลัพธ์
17. ห้ามอ้างว่าระบบทำงานได้บน macOS ทุกเวอร์ชัน หากยังไม่ได้ทดสอบตาม Compatibility Matrix
18. ห้ามเปิดเผย Source Code, Environment Variables, Tokens, API Keys หรือข้อมูลส่วนตัวผ่าน Log หรือ UI
19. ห้ามเพิ่ม Dependency ใหม่โดยไม่ประเมินความจำเป็น ความเสี่ยง และผลกระทบต่อขนาดแอป
20. หากข้อมูลไม่เพียงพอ ให้ระบุว่าไม่ทราบและเสนอวิธีตรวจสอบ ห้ามแต่งคำตอบขึ้นมาเอง

## 0.2 วิธีคิดที่ต้องใช้

ก่อนเสนอหรือสร้างฟีเจอร์ ให้ตอบคำถามเหล่านี้:

- ปัญหาจริงของผู้ใช้คืออะไร?
- ปัญหานี้เกิดขึ้นบ่อยแค่ไหน?
- ผู้ใช้มีวิธีแก้ปัญหาอยู่แล้วหรือไม่?
- MyNotchApp ช่วยลดขั้นตอนหรือเวลาของผู้ใช้ได้จริงหรือไม่?
- ผู้ใช้เข้าใจสิ่งที่แสดงบน Notch ได้หรือไม่?
- ระบบตรวจจับข้อมูลได้ถูกต้องเพียงใด?
- มี False Positive หรือไม่?
- ถ้าระบบตรวจจับผิด ผู้ใช้จะได้รับผลกระทบอย่างไร?
- มีวิธีแก้ปัญหาที่ง่ายกว่านี้หรือไม่?
- ฟีเจอร์นี้เหมาะกับพื้นที่ Notch จริงหรือไม่?
- ฟีเจอร์นี้คุ้มค่ากับ CPU, RAM, Battery และ Maintenance Cost หรือไม่?
- ฟีเจอร์นี้ทำให้ผลิตภัณฑ์ซับซ้อนขึ้นมากกว่าประโยชน์ที่ได้รับหรือไม่?

**หากฟีเจอร์ไม่มีคุณค่าชัดเจน ไม่ควรพัฒนาเพียงเพราะสามารถพัฒนาได้**

---

# 1. Product Overview

## 1.1 Product Identity

**MyNotchApp**

แนวคิดหลัก:

> Your development environment, understood.

คำอธิบาย:

MyNotchApp คือ Native macOS Companion สำหรับ Developer ที่ใช้พื้นที่ Notch เป็นศูนย์กลางในการรับรู้สถานะของ Development Environment โดยไม่ต้องสลับหน้าต่างหรือเปิดเครื่องมือต่าง ๆ เพื่อตรวจสอบสถานะทุกครั้ง

ผลิตภัณฑ์ควรทำให้ Developer สามารถ:

- เห็นสิ่งสำคัญได้ทันที
- เข้าใจว่าเกิดอะไรขึ้น
- ทราบว่าสิ่งใดต้องได้รับความสนใจ
- ดำเนินการแก้ไขได้อย่างรวดเร็ว
- กลับไปทำงานหลักได้โดยไม่ถูกรบกวน

MyNotchApp ไม่ควรเป็น Dashboard ที่ถูกย่อให้เล็กลง แต่ควรเป็น Context-Aware Developer Interface ที่แสดงข้อมูลตามความสำคัญและสถานการณ์

## 1.2 Core Product Philosophy

### Principle A: Glance → Understand → Act

ประสบการณ์การใช้งานแบ่งเป็น 3 ระดับ

**Glance — มองเห็น**

เมื่อผู้ใช้เหลือบมอง Notch ควรเข้าใจสถานะสำคัญได้ภายในเวลาประมาณ 1 วินาที

ตัวอย่าง:

- Build สำเร็จ
- มี Test ไม่ผ่าน
- AI Agent กำลังรอการยืนยัน
- Dev Server หยุดทำงาน
- มี Error ใหม่

**Understand — เข้าใจ**

เมื่อผู้ใช้เปิด Expanded Notch ควรเข้าใจว่าเกิดอะไรขึ้น สาเหตุคืออะไร และเกี่ยวข้องกับส่วนใดของโปรเจกต์

เป้าหมายเบื้องต้น: เข้าใจเหตุการณ์ได้ภายในประมาณ 3–5 วินาที โดยไม่ต้องเปิด Documentation

**Act — ลงมือทำ**

ผู้ใช้ควรดำเนินการต่อได้ด้วยการคลิกให้น้อยที่สุด เช่น:

- เปิดไฟล์ที่มีปัญหา
- เปิด Terminal
- Copy Error
- เปิด Browser
- ดู Test Failure
- หยุดหรือ Restart Process
- ตรวจสอบ AI Agent ที่กำลังรอ

ตัวเลขข้างต้นเป็นเป้าหมายสำหรับการออกแบบและ Usability Testing ไม่ใช่ผลลัพธ์ที่ยืนยันแล้ว

### Principle B: Clarity Over Decoration

ความเข้าใจสำคัญกว่าความสวยงาม

ห้ามใช้ Animation, Gradient, Glow หรือ Visual Effect เพื่อกลบข้อจำกัดของข้อมูล

Visual Design ต้องช่วยให้ผู้ใช้รับรู้สถานะได้เร็วขึ้นจริง

### Principle C: Progressive Disclosure

แสดงเฉพาะข้อมูลที่จำเป็นในแต่ละระดับ

ไม่ควรนำข้อมูลทุกอย่างมาแสดงพร้อมกัน

### Principle D: Trustworthy Information

ข้อมูลทุกอย่างที่แสดงต้องมีที่มาและมีระดับความเชื่อมั่นที่เหมาะสม

หากตรวจสอบไม่ได้ ต้องแสดงว่าไม่ทราบ ไม่ใช่สร้างข้อมูลขึ้นมาแทน

### Principle E: Native macOS Experience

ประสบการณ์ต้องสอดคล้องกับ macOS:

- ใช้งานลื่นไหล
- รองรับ Dark Mode และ Light Mode ตามความเหมาะสม
- รองรับ Keyboard Navigation
- เคารพ Accessibility
- เคารพ System Permissions
- ไม่ใช้ทรัพยากรเกินจำเป็น
- ไม่รบกวน Workflow ของผู้ใช้

---

# 2. Current Project Baseline

ส่วนนี้เป็นข้อมูลที่เจ้าของโปรเจกต์ระบุไว้ก่อนเริ่มแผนงาน AI ต้องตรวจสอบกับ Repository อีกครั้ง

## 2.1 Existing Technology Stack

| Component | Current Information |
|---|---|
| Language | Swift 6 |
| UI | AppKit + SwiftUI |
| Architecture | Unidirectional State Management |
| State Store | NotchStore |
| Reducer | NotchReducer |
| Side Effects | Effects |
| Notch Integration | NotchKit |
| Concurrency | Swift 6 Strict Concurrency |
| Testing | 116 Unit Tests ผ่านตามข้อมูลเดิม |
| Development Integration | Local Event Bus + Shell Hooks |
| Application | MyNotchApp.app |
| Local Certificate | MyNotchApp Local Dev |
| Target Hardware | Apple Silicon |

**ข้อควรระวัง:** ตัวเลข 116 Tests เป็นข้อมูลจากสถานะที่เจ้าของโปรเจกต์รายงานไว้ ไม่ใช่ผลการทดสอบในรอบปัจจุบัน ต้องรัน Test Suite จริงและตรวจสอบจำนวน Test ที่ถูกค้นพบก่อนใช้ตัวเลขนี้เป็น Baseline

## 2.2 Existing Architecture

แนวทาง State Management ปัจจุบัน:

- NotchStore
- NotchReducer
- Effects
- Unidirectional State Flow

แนวทางนี้ควรถูกเก็บไว้หาก Repository Audit พบว่ายังเหมาะสมและไม่มีปัญหาเชิงโครงสร้างที่มีหลักฐานชัดเจน

ไม่ควรเปลี่ยนไปใช้ Architecture อื่นเพียงเพราะ AI มีความคุ้นเคยกับรูปแบบนั้นมากกว่า

## 2.3 Existing Features

### Developer Cockpit

| Feature | รายละเอียด |
|---|---|
| Local Event Bus | รับ Event จาก CLI และ Script |
| Shell Hooks | ส่ง Toast, Progress, Activity และ Error Log |
| AI Agent Inbox | ตรวจจับสถานะ Agent ผ่าน AntigravityWatcher |
| Dev Server Detection | ตรวจจับ Development Server และ Port |
| Docker Glance | ตรวจสอบ Container |
| Server Actions | Open, Copy URL, Restart, Kill |
| Log Pin | ปักหมุด Log |
| Live Error Lens | อ่าน Error จาก Log |
| Git & GitHub Pulse | Branch, Dirty Files, Ahead/Behind |
| Command Palette | ค้นหาและสั่ง Project Tasks |
| Repo Task Runner | อ่าน package.json, Makefile และ Package.swift |
| Smart Clipboard | Decode JSON, JWT, Unix Timestamp และ Base64 |
| Quick AI | Gemini Chat |
| Voice-to-Notch | Voice Command และ OCR |

### OS Experience / Utility

| Feature | รายละเอียด |
|---|---|
| Lock Screen Overlay | ระบบ Overlay บน macOS Lock Screen |
| Face ID Integration | ใช้ความสามารถที่เกี่ยวข้องกับ Face ID |
| Music Integration | แสดงเพลงและปกเพลง |
| Lyrics | LRCLib / NetEase พร้อม Offset |
| Liquid Aurora | Metal GPU Visual Effect |
| Edge Glow | แสงขอบตามสถานะ |
| Custom HUD | ปรับแต่ง HUD |
| SceneKit Pop-up | โมเดล 3D เมื่อเชื่อมต่ออุปกรณ์ |
| Widget Studio | เปิด/ปิด Widget |
| Live Preview | Preview การปรับแต่ง |
| Ear Status Pills | CPU / RAM / Battery / Time |
| Hover Behavior | Smart Hover / Fixed |
| Gesture | Swipe 2 Fingers |
| File Tray | จัดเก็บไฟล์ชั่วคราว |
| AirDrop | ส่งไฟล์ |
| Screenshot Shelf | จัดเก็บ Screenshot |

### Features ที่เจ้าของโปรเจกต์ตั้งใจตัดออกจาก Notch

- Notes
- Todo Task
- Focus / Pomodoro
- Camera Mirror

ห้ามนำฟีเจอร์เหล่านี้กลับมาโดยไม่มีการทบทวน Product Direction ร่วมกับเจ้าของโปรเจกต์

## 2.4 สิ่งที่ต้องตรวจสอบก่อนพัฒนา

AI ต้องทำ Repository Audit โดยตรวจสอบ:

1. โครงสร้าง Directory จริง
2. App Entry Point
3. NotchKit Integration
4. Store / Reducer / Effects
5. Event Sources
6. Event Models
7. State Models
8. Existing Watchers
9. File System Monitoring
10. Process Monitoring
11. Docker Integration
12. Git Integration
13. Logging System
14. Notification System
15. Settings Architecture
16. Dependency List
17. Existing Unit Tests
18. Integration Tests
19. Build Configuration
20. Signing และ Entitlements
21. macOS Deployment Target
22. Error Handling
23. Concurrency Boundaries
24. Resource Consumption

ผลลัพธ์ต้องเป็นเอกสาร Audit แยกต่างหาก โดยแยกสถานะ:

- Implemented and Verified
- Implemented but Not Verified
- Partially Implemented
- Not Implemented
- Broken
- Unknown
- Deprecated / Planned for Removal

ห้ามนำ Planned Feature มาแสดงเป็น Implemented Feature

---

# 3. Target Users & Real-World Problems

## 3.1 Primary Target Audience

Developer ที่ใช้ macOS เป็นเครื่องมือทำงานหลัก

กลุ่มที่ควรพิจารณา:

1. Frontend Developer
2. Backend Developer
3. Full-Stack Developer
4. iOS / macOS Developer
5. Unity Developer
6. DevOps / Platform Engineer
7. Developer ที่ทำงานกับ Docker และ Local Services
8. Developer ที่ใช้ AI Coding Agents
9. Developer ที่ทำงานหลาย Repository
10. Developer ที่ทำงานกับหลาย Process พร้อมกัน

## 3.2 User Experience Levels

ผลิตภัณฑ์ต้องไม่ออกแบบโดยสมมติว่าผู้ใช้ทุกคนเป็น Senior Developer

ควรคำนึงถึงผู้ใช้ 3 กลุ่ม:

**Beginner**

- อาจไม่เข้าใจ Port Conflict
- อาจไม่รู้จัก Orphan Process
- อาจไม่ทราบว่า Test Failure หมายถึงอะไร
- ต้องการคำอธิบายที่อ่านแล้วเข้าใจ

**Intermediate**

- รู้จัก Git, Build, Test, API, Docker
- ต้องการความรวดเร็ว
- ไม่ต้องการคำอธิบายพื้นฐานมากเกินไป

**Advanced**

- เข้าใจ Technical Details
- ต้องการข้อมูลเชิงลึก
- ต้องการเข้าถึง Log, PID, Exit Code, File Path และ Process Tree

ดังนั้นระบบควรมี Simple View และ Technical Details แยกกัน

## 3.3 Real User Problems

ตัวอย่างปัญหาที่ MyNotchApp ควรช่วยแก้:

| Problem | Typical Situation | Desired Benefit |
|---|---|---|
| Build Failure | Build ไม่ผ่านแต่ไม่เห็น Error | เห็นสาเหตุได้ทันที |
| Test Failure | ต้องเปิด Terminal เพื่อดู Test | เห็น Test ที่ล้มเหลว |
| Port Conflict | Server เปิดไม่ได้เพราะ Port ถูกใช้ | รู้ว่าใครกำลังใช้ Port |
| AI Agent Waiting | Agent รอการยืนยัน | ไม่พลาดการตอบสนอง |
| Agent Conflict | หลาย Agent แก้ไฟล์เดียวกัน | ลดโอกาสชนกัน |
| Server Crash | Local Server หยุดทำงาน | ทราบทันที |
| Docker Failure | Container หยุดหรือ Restart Loop | เห็นสถานะผิดปกติ |
| Git Changes | ลืมว่ามีไฟล์เปลี่ยนแปลง | เห็นภาพรวมการเปลี่ยนแปลง |
| Deployment Failure | CI/CD ไม่สำเร็จ | ทราบสถานะและขั้นตอนที่ล้มเหลว |

อย่าพัฒนาฟีเจอร์เพียงเพราะปัญหาเหล่านี้มีอยู่ในทางทฤษฎี ต้องตรวจสอบว่าผู้ใช้เป้าหมายพบปัญหาจริงและต้องการให้แอปช่วยแก้หรือไม่

---

# 4. Product UX Architecture

## 4.1 Three-Level Interface

MyNotchApp ต้องมี Interface ที่เข้าใจง่ายในพื้นที่จำกัด

### Level 1 — Collapsed Notch

วัตถุประสงค์: แสดงสถานะสำคัญโดยไม่รบกวน

สิ่งที่ควรแสดง:

- Build / Test Status
- Active AI Agent
- Critical Error
- Server Health
- Important Activity

ข้อกำหนด:

- ไม่แสดงข้อมูลทุกหมวดพร้อมกัน
- ไม่แสดงตัวเลขจำนวนมากโดยไม่มีความหมาย
- ไม่ใช้ Icon ที่ผู้ใช้ต้องเดา
- ใช้สีร่วมกับ Icon หรือข้อความ ไม่ใช้สีอย่างเดียว
- สถานะต้องไม่กระพริบหรือเปลี่ยนบ่อยจนรบกวน
- ถ้าไม่มีข้อมูล ไม่ควรสร้าง Widget ว่างเปล่า
- ต้องมีลำดับความสำคัญที่ชัดเจน

ตัวอย่าง:

`Build Failed`

`2 Tests Failed`

`Agent Waiting`

`Server Stopped`

ไม่ควรแสดง:

`B: 1 | T: 2 | A: 3 | P: 3000 | CPU: 42% | RAM: 68%`

เพราะผู้ใช้ต้องตีความข้อมูลมากเกินไป

### Level 2 — Expanded Notch

วัตถุประสงค์: ช่วยให้ผู้ใช้เข้าใจเหตุการณ์

ข้อมูลที่แสดงควรมี:

1. สิ่งที่เกิดขึ้น
2. เกิดขึ้นกับโปรเจกต์ใด
3. สาเหตุหรือหลักฐานที่พบ
4. ระดับความสำคัญ
5. เวลา
6. ทางเลือกในการดำเนินการ

ตัวอย่าง:

**Build ไม่สำเร็จ**

Project: MusicGear Hub

พบข้อผิดพลาด 2 รายการ

- `ProductService.swift`
- Line 42
- Cannot find type 'ProductDTO'

Actions:

- Open File
- Copy Error
- View Details

รายละเอียดเชิงเทคนิคควรซ่อนได้และเปิดดูได้เมื่อผู้ใช้ต้องการ

### Level 3 — Toast / Notification

ใช้เฉพาะเหตุการณ์ที่มีความสำคัญจริง

ตัวอย่าง:

- Build Failed
- Test Failed
- Agent Waiting for Approval
- Server Crashed
- Deployment Failed

ห้ามแจ้งทุก Event ที่เข้ามา

ต้องมี:

- Deduplication
- Cooldown
- Priority
- User Preferences
- Quiet Mode
- Notification History
- Clear / Dismiss

## 4.2 Language System

ข้อความต้องใช้ภาษาที่มนุษย์เข้าใจได้

ตัวอย่าง Mapping:

| Technical Term | User-Friendly Label |
|---|---|
| Build Failed | Build ไม่สำเร็จ |
| Test Failure | มี Test ไม่ผ่าน |
| Port Conflict | Port นี้กำลังถูกใช้งาน |
| Orphan Process | พบโปรแกรมที่อาจค้างอยู่ |
| Agent Conflict | AI กำลังแก้ไฟล์เดียวกัน |
| Schema Drift | โครงสร้าง Database ไม่ตรงกัน |
| Dependency Vulnerability | พบช่องโหว่ใน Package |
| Deployment Failed | Deploy ไม่สำเร็จ |
| Process Terminated | โปรแกรมหยุดทำงาน |
| Connection Timeout | เชื่อมต่อไม่สำเร็จภายในเวลาที่กำหนด |

Technical Details สามารถแสดงชื่อจริงของ Error และข้อมูลเชิงเทคนิคได้

อย่าทำให้ข้อความง่ายจนความหมายทางเทคนิคผิดเพี้ยน

## 4.3 Visual Semantics

สีต้องมีความหมายคงที่:

| Color | Meaning |
|---|---|
| Green | สำเร็จ / ปกติ |
| Red | ต้องแก้ไข / เกิด Failure |
| Yellow | ควรตรวจสอบ / Warning |
| Gray | ไม่ทำงาน / ไม่มีข้อมูล |
| Purple | AI Activity |

ข้อกำหนดเพิ่มเติม:

- ห้ามใช้สีเป็นตัวบอกสถานะเพียงอย่างเดียว
- รองรับ Accessibility
- รองรับ Contrast
- ห้ามใช้สีแดงทุกครั้งที่มี Activity
- Warning ไม่ควรมีน้ำหนักเท่ากับ Critical Failure

## 4.4 Interaction Rules

ทุกปุ่มต้องมีหน้าที่ชัดเจน

ตัวอย่าง:

- Open: เปิดสิ่งที่เกี่ยวข้อง
- Copy: คัดลอกข้อมูล
- Retry: ลองดำเนินการใหม่
- Restart: Restart Process
- Stop: หยุด Process
- Details: แสดงรายละเอียด

Action ที่มีความเสี่ยงต้องมี Confirmation หรือวิธีป้องกันที่เหมาะสม

ตัวอย่าง Action ที่ต้องระมัดระวัง:

- Kill Process
- Delete File
- Stop Container
- Modify Configuration
- Run Shell Command
- Restart Service

ห้ามทำ Destructive Action โดยอาศัยการคลิกผิดเพียงครั้งเดียว

---

# 5. Proposed Developer Intelligence Architecture

ส่วนนี้เป็น Architecture เป้าหมายที่เสนอให้ศึกษา ไม่ใช่คำสั่งให้เขียนระบบใหม่ทันที

## 5.1 High-Level Architecture

```text
                    DATA SOURCES
                         |
       +-----------------+-----------------+
       |                 |                 |
   Shell Hooks       File Events       Process Events
       |                 |                 |
   Build/Test         Log Files         Servers
       |                 |                 |
       +-----------------+-----------------+
                         |
                 EVENT NORMALIZATION
                         |
             Validate / Normalize / Deduplicate
                         |
                 EVENT CORRELATION
                         |
              DEVELOPER INTELLIGENCE
                         |
        +----------------+----------------+
        |                |                |
    Rule Engine      State Analysis    Risk Analysis
        |                |                |
        +----------------+----------------+
                         |
                  NOTCH STORE
                         |
                    REDUCER
                         |
                     EFFECTS
                         |
        +----------------+----------------+
        |                |                |
     Collapsed        Expanded          Toast
       Notch            Notch        Notification
```

## 5.2 Architectural Principles

### Separation of Concerns

แต่ละ Layer ต้องมีความรับผิดชอบชัดเจน

**Data Sources**

ทำหน้าที่รับข้อมูลจากแหล่งต่าง ๆ

**Event Normalization**

ทำหน้าที่ตรวจสอบและแปลงข้อมูลให้อยู่ในรูปแบบกลาง

**Event Correlation**

เชื่อมโยง Event ที่เกี่ยวข้องกัน เช่น Build Failure กับ Error Log

**Developer Intelligence**

วิเคราะห์สถานะและประเมินความสำคัญ

**NotchStore / Reducer**

จัดการ State ตาม Architecture ปัจจุบัน

**UI**

แสดงข้อมูลและส่ง User Action กลับเข้าสู่ระบบ

ห้ามให้ Data Source เข้าถึง UI โดยตรงโดยไม่มีขอบเขตที่ชัดเจน

## 5.3 Event Model

ควรศึกษาและออกแบบ Event Schema กลาง โดยพิจารณาข้อมูลดังนี้:

```swift
struct DeveloperEvent {
    let id: UUID
    let source: EventSource
    let type: EventType
    let projectID: ProjectID?
    let timestamp: Date
    let severity: Severity
    let correlationID: UUID?
    let payload: EventPayload
}
```

ตัวอย่างนี้เป็นเพียงแนวคิด ต้องตรวจสอบกับ Model ที่มีอยู่จริงก่อนสร้างหรือแก้ไข

ข้อกำหนด:

- Event ต้องมี Unique ID
- ต้องระบุ Source
- ต้องมี Timestamp
- ต้องสามารถระบุ Project ได้เมื่อมีข้อมูล
- ต้องรองรับ Correlation
- ต้องรองรับ Event ที่ไม่เกี่ยวข้องกับ Project
- ต้องรองรับ Unknown Event
- ต้องตรวจสอบ Payload
- ต้องป้องกันข้อมูลซ้ำ
- ต้องไม่บันทึก Secret

ไม่ควรบังคับให้ทุก Event ต้องมีข้อมูลครบทุก Field หาก Event นั้นไม่มีข้อมูลดังกล่าวจริง

## 5.4 Project Identity

การระบุ Project ต้องไม่พึ่งพาเพียงชื่อ Folder

ควรพิจารณา:

- Canonicalized Repository Path
- Git Repository Root
- Project Metadata
- Stable Project Identifier
- Worktree Identity

หาก Project มีหลาย Worktree ต้องไม่รวมสถานะทั้งหมดเป็นโปรเจกต์เดียวโดยไม่มีการแยก Context

## 5.5 Event Correlation

ตัวอย่าง:

1. ผู้ใช้เริ่ม Build
2. Build Process ส่ง Started Event
3. Compiler ส่ง Error
4. Test Runner รายงาน Failure
5. Build Process ส่ง Exit Code
6. Intelligence Engine รวมข้อมูลเป็นเหตุการณ์เดียว

ผลลัพธ์ที่ควรเห็น:

**Build ไม่สำเร็จ**

พบ Error 2 รายการ

มี Test ไม่ผ่าน 1 รายการ

ผู้ใช้ไม่ควรได้รับ Notification 4–5 ครั้งจากเหตุการณ์เดียวกัน

ต้องออกแบบ Correlation Key และ Lifecycle ของ Event ให้ชัดเจน

## 5.6 Deterministic First, AI Second

กฎสำคัญ:

**ข้อมูลสถานะต้องมาจากแหล่งข้อมูลจริง ไม่ใช่การคาดเดาของ AI**

ใช้ Deterministic Logic สำหรับ:

- Build Status
- Test Results
- Process State
- Port Usage
- Docker State
- Git State
- Agent Activity
- Exit Code
- Error Location

ใช้ AI เมื่อจำเป็นสำหรับ:

- อธิบาย Error
- สรุป Log
- เสนอแนวทางแก้ไข
- อธิบายผลกระทบของการเปลี่ยนแปลง
- ช่วยตีความข้อมูลหลายแหล่ง

ห้ามใช้ AI เพื่อสร้างสถานะที่ระบบตรวจสอบไม่ได้

หาก AI ไม่สามารถอธิบายได้อย่างมีหลักฐาน ต้องแสดงว่าไม่สามารถสรุปได้

---

# 6. Development Roadmap

Roadmap นี้เป็นลำดับการศึกษาและพัฒนา ไม่ใช่การอนุญาตให้ AI ทำทุก Phase ต่อเนื่องโดยอัตโนมัติ

แต่ละ Phase ต้องผ่าน Gate ก่อนเริ่ม Phase ถัดไป

## Phase 0 — Repository Audit & Product Validation

**Priority: Critical**

เป้าหมาย: เข้าใจระบบเดิมก่อนเพิ่มระบบใหม่

งาน:

1. วิเคราะห์โครงสร้างโปรเจกต์
2. วิเคราะห์ Architecture
3. ตรวจสอบ Existing Features
4. ตรวจสอบ Test Suite
5. ตรวจสอบ Build Process
6. ตรวจสอบ Memory และ CPU Usage
7. ตรวจสอบ Event Flow
8. ตรวจสอบ Logging
9. ตรวจสอบ Error Handling
10. ตรวจสอบ Permissions
11. ตรวจสอบ Signing
12. ตรวจสอบ Distribution Constraints

Deliverables:

- `docs/audit/REPOSITORY_AUDIT.md`
- `docs/audit/ARCHITECTURE_AUDIT.md`
- `docs/audit/FEATURE_STATUS.md`
- `docs/audit/TEST_BASELINE.md`
- `docs/audit/RISK_REGISTER.md`

Acceptance Criteria:

- ระบุระบบที่มีอยู่จริงได้
- ระบุระบบที่ยังไม่สมบูรณ์ได้
- ระบุ Technical Debt ได้
- ระบุจุดเสี่ยงได้
- มี Test Baseline จากการรันจริง
- ไม่มีการแก้ไขระบบเดิมโดยไม่จำเป็น

**ห้ามเริ่ม Phase 1 จนกว่า Audit จะเพียงพอสำหรับการออกแบบ Integration**

## Phase 1 — Build & Test Intelligence

**Priority: P0**

เป้าหมาย: ทำให้ผู้ใช้เข้าใจสถานะ Build และ Test ได้โดยไม่ต้องเปิด Terminal ทุกครั้ง

### 1.1 Build Detection

พิจารณารองรับ:

- Swift / Xcode
- Node.js
- TypeScript
- .NET
- Unity
- Generic Shell Command

ห้ามสมมติว่า Build ทุกระบบมี Output รูปแบบเดียวกัน

ต้องใช้ Adapter แยกตาม Toolchain

### 1.2 Test Result Detection

พิจารณารองรับ:

- XCTest / Swift Testing
- Vitest
- Jest
- Playwright
- dotnet test
- Unity Test Framework

ต้องศึกษารูปแบบ Structured Output ของแต่ละระบบก่อน

หากมี JSON, XML หรือ JUnit Report ให้พิจารณาใช้ Structured Result มากกว่าการ Parse ข้อความ Terminal ด้วย Regex เพียงอย่างเดียว

### 1.3 Information to Display

- Build Started
- Build Success
- Build Failed
- Test Started
- Test Passed
- Test Failed
- Failed Test Count
- Failed Test Names
- Error File
- Error Line
- Exit Code
- Duration
- Last Run Time

ห้ามแสดง Field ที่ไม่มีข้อมูลจริง

### 1.4 UX Example

**Build สำเร็จ**

แสดงสถานะที่ชัดเจนและไม่ต้องมี Notification ที่รบกวนทุกครั้ง

**Build ไม่สำเร็จ**

แสดง:

- ชื่อ Project
- Error Summary
- จำนวน Error
- ตำแหน่งไฟล์
- ปุ่ม Open File
- ปุ่ม Copy Error

**Test ไม่ผ่าน**

แสดง:

- จำนวน Test ที่ไม่ผ่าน
- ชื่อ Test
- Failure Message
- ปุ่ม View Failed Tests

### 1.5 Technical Requirements

- Adapter-based Architecture
- Structured Parsing
- Process Lifecycle Tracking
- Exit Code Validation
- Event Correlation
- Timeout Handling
- Cancellation Support
- Duplicate Event Protection
- Unit Tests
- Integration Tests

### 1.6 Acceptance Criteria

1. ตรวจจับ Build Status จากแหล่งข้อมูลจริงได้
2. ตรวจจับ Exit Code ได้ถูกต้อง
3. แยก Build Failure กับ Test Failure ได้
4. ไม่สร้าง Failure เมื่อ Process สำเร็จ
5. ไม่สร้าง Success เมื่อ Process ยังไม่จบ
6. รองรับ Process ที่ถูกยกเลิก
7. รองรับ Output ที่ผิดรูปแบบ
8. แสดง Error ที่มีหลักฐานอ้างอิงได้
9. ไม่สร้าง Notification ซ้ำจาก Event เดียวกัน
10. UI ไม่ค้างระหว่าง Parsing
11. หากไม่รองรับ Toolchain ต้องแจ้งอย่างชัดเจน
12. Integration Test ต้องตรวจสอบทั้ง Success และ Failure

---

## Phase 2 — Agent Conflict Detection

**Priority: P0**

เป้าหมาย: ช่วย Developer ที่ทำงานร่วมกับ AI Coding Agents หลายตัว ลดโอกาสที่ Agent จะทำงานทับกัน

### 2.1 Agent Awareness

ตรวจสอบข้อมูล:

- Agent Name
- Session ID
- Repository
- Worktree
- Branch
- Current Activity
- Modified Files
- Last Activity
- Waiting for Approval
- Completed / Failed

ต้องแยกข้อมูลที่ตรวจพบจริงกับข้อมูลที่คาดการณ์

### 2.2 Conflict Detection

ตัวอย่าง:

Agent A กำลังแก้ไข `UserService.swift`

Agent B กำลังแก้ไข `UserService.swift`

ระบบควรแสดง:

**AI กำลังแก้ไฟล์เดียวกัน**

Agent A และ Agent B มีการทำงานที่เกี่ยวข้องกับไฟล์นี้

ผู้ใช้สามารถเปิดดูรายละเอียดได้

### 2.3 Conflict Types

- Same File Modified
- Same File Recently Modified
- Same Branch Concurrent Work
- Shared Worktree
- Unreviewed Changes
- Stale Session

ต้องแยก Conflict ที่ตรวจสอบได้จริงออกจาก Warning ที่อาจเกิดขึ้น

การที่ Agent สองตัวแก้ไฟล์เดียวกันไม่ได้หมายความว่าเกิด Git Conflict เสมอไป

### 2.4 Detection Strategy

พิจารณา:

- Agent Hooks
- Explicit Session Events
- Git Worktree
- File System Events
- File Modification Metadata
- Session Heartbeat

ห้ามใช้การตรวจจับไฟล์เปลี่ยนแปลงเพียงอย่างเดียวเพื่อสรุปว่า Agent ตัวใดเป็นผู้แก้ไข หากไม่มีข้อมูลเชื่อมโยงที่เชื่อถือได้

### 2.5 Acceptance Criteria

- ระบุ Agent ได้จากข้อมูลที่มีหลักฐาน
- ระบุ Repository และ Worktree ได้ถูกต้อง
- แยก Agent Activity กับ File Modification ได้
- ตรวจจับ Same File Activity ได้
- แสดงระดับความเชื่อมั่น
- ไม่กล่าวหาว่าเกิด Conflict หากยังไม่มีหลักฐาน
- ไม่สร้าง Notification ซ้ำ
- รองรับ Agent ที่ไม่ได้ติดตั้ง Integration
- สามารถปิด Integration ได้โดยไม่กระทบระบบหลัก

---

## Phase 3 — Port & Process Intelligence

**Priority: P0**

เป้าหมาย: ช่วยแก้ปัญหา Port Conflict และ Process ที่ผิดปกติ

### 3.1 Process Information

พิจารณาแสดง:

- Process Name
- PID
- Parent PID
- Port
- Local Address
- Process State
- Start Time
- Executable Path เมื่อเข้าถึงได้
- Associated Project เมื่อระบุได้จริง

### 3.2 Port Conflict

ตัวอย่าง:

**Port 3000 กำลังถูกใช้งาน**

พบ Process:

- Name: node
- PID: 4821
- Port: 3000

Actions:

- View Process
- Open Terminal
- Copy PID
- Stop Process

### 3.3 Safety

การหยุด Process เป็นการกระทำที่มีความเสี่ยง

ต้อง:

- แสดงชื่อ Process
- แสดง PID
- แสดง Port
- แสดงผลกระทบที่ทราบ
- ขอ Confirmation ก่อน Kill
- ไม่ Kill System Process โดยอัตโนมัติ
- ไม่ Kill Process ที่ไม่ทราบตัวตน
- จัดการ Permission Error อย่างถูกต้อง

ห้ามใช้ `kill -9` เป็น Default Action

ควรพิจารณา Graceful Termination ก่อน และใช้ Force Termination เฉพาะเมื่อผู้ใช้ยืนยันและระบบรองรับ

### 3.4 Orphan Process

คำว่า Orphan Process ต้องใช้ด้วยความระมัดระวัง

Process ที่ไม่มี Parent Process ตามที่คาดไว้ ไม่ได้หมายความว่าเป็น Process ที่ค้างหรือไม่จำเป็นเสมอไป

ต้องใช้หลักฐานอื่นร่วมด้วยก่อนแจ้งเตือน

### 3.5 Acceptance Criteria

- ตรวจสอบ Port ได้ถูกต้อง
- ระบุ PID ได้ถูกต้อง
- แยก Process ที่มีสิทธิ์เข้าถึงไม่ได้
- ไม่มี Automatic Kill
- รองรับ Permission Denied
- ไม่สรุปว่า Process เป็น Orphan จากข้อมูลที่ไม่เพียงพอ
- ตรวจสอบ Process ที่หายไประหว่างการอ่านข้อมูลได้
- ไม่ทำให้ UI ค้าง

---

## Phase 4 — Change Impact Intelligence

**Priority: P0**

เป้าหมาย: ช่วยให้ Developer เข้าใจว่าการเปลี่ยนแปลงหนึ่งครั้งอาจกระทบส่วนใดของระบบ

### 4.1 Information Sources

- Git Diff
- Changed Files
- Project Structure
- Dependency Graph
- Compiler Diagnostics
- Test Mapping
- Build Configuration

### 4.2 Example

ผู้ใช้แก้ไข:

`UserService.swift`

ระบบพบว่า:

- มีไฟล์ที่ Import Service นี้ 4 ไฟล์
- มี Test ที่เกี่ยวข้อง 3 ชุด
- มี Model ที่ถูกใช้งานร่วมกัน

แสดง:

**พบการเปลี่ยนแปลงที่อาจกระทบส่วนอื่น**

Suggested Checks:

- UserServiceTests
- UserRepositoryTests
- AuthenticationTests

ต้องแสดงว่าเป็น Suggested Tests ไม่ใช่การยืนยันว่า Test เหล่านี้ได้รับผลกระทบแน่นอน

### 4.3 Rules

- ต้องมีที่มาของ Dependency
- ต้องแยก Direct Dependency กับ Inferred Dependency
- ต้องไม่อ้างว่าตรวจสอบได้ครบทุกกรณี
- ต้องไม่รัน Test จำนวนมากโดยไม่ถามหรือไม่มี User Policy รองรับ
- ต้องไม่ใช้ LLM วิเคราะห์ทุก Git Event
- ต้องแสดงเหตุผลของ Recommendation

### 4.4 Acceptance Criteria

- แสดง Changed Files ได้ถูกต้อง
- แสดง Dependency ที่มีหลักฐาน
- ระบุระดับความมั่นใจ
- แนะนำ Test พร้อมเหตุผล
- ไม่สร้างผลกระทบที่ไม่มีหลักฐาน
- ไม่ทำให้ Git Operation ช้าลงอย่างมีนัยสำคัญ

---

## Phase 5 — Service Health & Docker Intelligence

**Priority: P1**

เป้าหมาย: ช่วยให้ผู้ใช้เห็นสุขภาพของ Local Development Environment

### 5.1 Service Monitoring

พิจารณาตรวจสอบ:

- Running
- Stopped
- Crashed
- Restarting
- Unhealthy
- Unknown

### 5.2 Docker

พิจารณาข้อมูล:

- Container Name
- Container State
- Image
- Restart Count
- Health Status
- Exposed Ports
- Last State Change

ต้องแยก Docker Engine Unavailable กับ Container Stopped

### 5.3 Service Dependencies

ตัวอย่าง:

```text
Frontend
   |
   v
Backend API
   |
   +---- PostgreSQL
   |
   +---- Redis
```

หาก Redis ไม่ทำงาน ต้องไม่สรุปว่า Backend พังทั้งหมดโดยไม่มีการตรวจสอบ

ควรแสดง Dependency ที่ได้รับผลกระทบอย่างชัดเจน

### 5.4 Acceptance Criteria

- ตรวจสอบสถานะจาก Docker API หรือแหล่งข้อมูลที่เชื่อถือได้
- ไม่ใช้ Container Name เป็น Unique Identity เพียงอย่างเดียว
- รองรับ Docker ไม่ได้ติดตั้ง
- รองรับ Docker Engine ไม่ทำงาน
- แยก Unknown กับ Stopped
- ไม่ Restart Container โดยอัตโนมัติ
- ไม่แสดง Health Status ที่ไม่มีข้อมูลรองรับ

---

## Phase 6 — CI/CD & Deployment Watchtower

**Priority: P1**

เป้าหมาย: ให้ผู้ใช้เห็นสถานะ Pipeline และ Deployment

พิจารณารองรับ:

- GitHub Actions
- Build Pipeline
- Test Pipeline
- Deployment
- Release
- Production Health

ข้อมูลที่ควรแสดง:

- Repository
- Branch
- Commit
- Workflow
- Job
- Status
- Started At
- Completed At
- Failure Summary
- Link to Run

ข้อกำหนด:

- API Token ต้องปลอดภัย
- ใช้ Least Privilege
- ไม่แสดง Secret
- มี Rate Limit Handling
- แยกข้อมูลเก่ากับข้อมูลปัจจุบัน
- แสดงเวลาที่ Sync ล่าสุด
- หาก API ติดต่อไม่ได้ ต้องแสดง Unknown / Connection Error

ห้ามใช้ข้อมูล Cached มานำเสนอว่าเป็นสถานะ Live

---

## Phase 7 — Database & Migration Intelligence

**Priority: P1**

เป้าหมาย: ช่วยตรวจสอบสถานะ Database และ Migration

พิจารณา:

- Pending Migration
- Failed Migration
- Migration History
- Schema Drift
- Connection Failure
- Database Availability
- Migration Environment

ต้องแยก Database ที่เชื่อมต่อไม่ได้ออกจาก Database ที่ Schema ไม่ตรงกัน

ห้ามรัน Migration หรือแก้ไข Schema โดยอัตโนมัติ

Migration เป็นงานที่อาจส่งผลต่อข้อมูลจริง ต้องมีการตรวจสอบและยืนยัน

Acceptance Criteria:

- แสดงสถานะจากแหล่งข้อมูลจริง
- ไม่เปิดเผย Connection String
- ไม่แสดง Password
- ไม่สั่ง Migration โดยไม่มีการยืนยัน
- รองรับ Database ที่ไม่มี Integration
- แสดง Last Checked Time
- แสดง Failure Reason เมื่อมีหลักฐาน

---

## Phase 8 — Dependency & Security Watcher

**Priority: P1**

เป้าหมาย: ช่วยให้ผู้ใช้ทราบความเสี่ยงของ Dependencies

พิจารณา:

- npm / pnpm
- NuGet
- Swift Package Manager
- Unity Packages
- Dependency Vulnerabilities
- Deprecated Packages
- License Metadata

ข้อกำหนด:

- ต้องแสดง Package Name
- ต้องแสดง Version
- ต้องแสดง Advisory Source
- ต้องแสดง Severity
- ต้องแสดงเวลาที่ตรวจสอบ
- ต้องแยก Vulnerability ที่ยืนยันแล้วออกจากข้อสงสัย
- ต้องไม่ Update Package อัตโนมัติ
- ต้องไม่ส่งข้อมูล Source Code โดยไม่จำเป็น

การแสดง Security Warning ต้องมีหลักฐานและแหล่งอ้างอิง

---

## Phase 9 — API Contract & Environment Guard

**Priority: P1**

### API Monitor

พิจารณา:

- Endpoint Availability
- Response Status
- Latency
- Timeout
- OpenAPI Contract
- Failed Health Check

ห้ามส่ง Request ไปยัง Endpoint ที่มีผลข้างเคียงโดยไม่ตั้งใจ

Health Check ต้องเป็น Safe Request

### Environment Guard

พิจารณา:

- Required Environment Variables
- Missing Configuration
- `.env.example` Mismatch
- Environment-specific Configuration
- Invalid Configuration

ข้อกำหนด:

- ไม่อ่าน Secret มาแสดงบน UI
- ไม่บันทึก Secret ใน Log
- แสดงเฉพาะชื่อ Variable ที่ขาดหรือผิด
- ไม่ส่ง Environment Variables ออกไปยัง AI Service
- ต้องมี Redaction ก่อน Log ทุกครั้ง

---

## Phase 10 — Release Readiness

**Priority: P2**

เป้าหมาย: รวมสถานะสำคัญเพื่อช่วย Developer ประเมินความพร้อมก่อน Release

ตัวอย่าง Checklist:

- Build ผ่าน
- Test ผ่าน
- Git Working Tree ตรวจสอบแล้ว
- ไม่มี Critical Failure ที่ยังไม่จัดการ
- Migration ตรวจสอบแล้ว
- CI ผ่าน
- Security ตรวจสอบแล้ว
- Changes Reviewed แล้ว

ห้ามแสดง Release Ready หากยังมีข้อมูลสำคัญที่ไม่ได้ตรวจสอบ

ควรมีสถานะ:

- Ready
- Needs Attention
- Blocked
- Unknown

Unknown ต้องไม่ถูกนับเป็น Passed

---

# 7. Features That Must Be Evaluated Separately

## 7.1 Lock Screen / Face ID

ฟีเจอร์นี้มีความซับซ้อนและความเสี่ยงมากกว่าฟีเจอร์ Developer Cockpit ทั่วไป

ต้องตรวจสอบ:

- Public API Availability
- Private API Dependency
- Entitlements
- macOS Version Compatibility
- App Sandbox
- Signing
- Notarization
- Gatekeeper
- Security Model
- Lock Screen Lifecycle
- Failure Recovery

ห้ามอ้างว่า Face ID Integration หรือ Lock Screen Overlay สามารถใช้งานกับทุกเครื่องได้ หากยังไม่ได้พิสูจน์

ห้ามทำให้ Core Developer Cockpit ต้องพึ่งพาฟีเจอร์ Lock Screen

**ข้อเสนอ:** แยก OS Experience เป็น Experimental Module จนกว่าจะพิสูจน์ความเสถียรและความสามารถในการ Distribution ได้

## 7.2 Metal Visual Effects

ควรประเมิน:

- GPU Usage
- Frame Rate
- Memory
- Battery Impact
- Thermal Impact
- Animation Lifecycle
- Reduced Motion
- Low Power Mode

Visual Effect ต้องลดระดับหรือหยุดทำงานเมื่อไม่จำเป็น

ห้ามให้ Animation ทำงานตลอดเวลาโดยไม่มีเหตุผล

## 7.3 Custom HUD / SceneKit

ควรพิจารณาความเหมาะสมกับ Native macOS Experience

ต้องทดสอบ:

- การแสดงผล
- การปิด Overlay
- การสลับหน้าต่าง
- การเชื่อมต่อและตัดการเชื่อมต่ออุปกรณ์
- Memory Lifecycle
- Resource Cleanup

## 7.4 Widget Studio

ต้องมี:

- Enable / Disable
- Preview
- Reset to Default
- Configuration Persistence
- Invalid Configuration Handling
- Accessibility
- Keyboard Navigation

ไม่ควรให้ผู้ใช้ต้องตั้งค่ามากมายก่อนจะใช้งานฟีเจอร์หลักได้

---

# 8. Public Beta Strategy

MyNotchApp ควรออกแบบให้ Developer คนอื่นสามารถทดลองใช้ได้โดยไม่ต้องให้ผู้พัฒนาคอยอธิบายทุกอย่าง

## 8.1 First-Run Experience

เมื่อเปิดแอปครั้งแรก:

1. อธิบายว่า MyNotchApp คืออะไร
2. อธิบายข้อมูลที่แอปสามารถตรวจสอบได้
3. ให้ผู้ใช้เลือก Integration ที่ต้องการ
4. แสดง Permission ที่จำเป็น
5. อธิบายเหตุผลของ Permission
6. เปิดใช้งานเฉพาะสิ่งที่ผู้ใช้ยินยอม
7. แสดงตัวอย่างการใช้งาน
8. ให้ผู้ใช้เริ่มใช้งานได้โดยไม่ต้องตั้งค่าทุกอย่าง

ห้ามขอ Permission ทุกอย่างตั้งแต่เริ่มต้นโดยไม่มีเหตุผล

## 8.2 Project Detection

ควรมีวิธีตรวจสอบ Project ที่ใช้งานอยู่ เช่น:

- Git Repository
- Working Directory
- Process Metadata
- Explicit Project Registration

หากไม่สามารถระบุ Project ได้ ต้องแสดงว่าไม่ทราบ

ห้ามเลือก Project ผิดโดยอัตโนมัติ

## 8.3 Integration Settings

ควรแยก Integration เป็นหมวด:

- Git
- Build & Test
- AI Agents
- Docker
- Local Servers
- CI/CD
- Database
- Security

แต่ละ Integration ต้องมี:

- Status
- Permission
- Enable / Disable
- Last Checked
- Error State
- Configuration
- Documentation Link

## 8.4 Privacy & Data Control

ผู้ใช้ต้องเข้าใจว่า:

- แอปเก็บข้อมูลอะไร
- เก็บไว้ที่ใด
- ส่งข้อมูลออกไปหรือไม่
- ใช้ AI Service หรือไม่
- ข้อมูลใดถูกส่งไปยัง AI
- สามารถปิดการส่งข้อมูลได้หรือไม่
- สามารถลบประวัติได้อย่างไร

Default ควรเป็น Local-First

ไม่ควรส่ง Source Code, Logs, File Paths, Environment Variables หรือข้อมูลส่วนตัวออกไปโดยไม่มีความจำเป็นและการยินยอมที่เหมาะสม

## 8.5 Diagnostics Export

ควรมีระบบ Export Diagnostics เพื่อให้ผู้ใช้ส่งข้อมูลสำหรับการแก้ปัญหาได้

ต้องมี Redaction:

- API Keys
- Tokens
- Passwords
- Environment Variables
- Personal File Paths เมื่อไม่จำเป็น
- Sensitive Log Content

ผู้ใช้ควรตรวจสอบข้อมูลก่อน Export

## 8.6 Multi-language

ควรเตรียมระบบ Localization

ภาษาเริ่มต้นอาจเป็นภาษาอังกฤษสำหรับ Developer Audience แต่ต้องไม่ Hardcode ข้อความทุกจุดจนขยายภาษาไม่ได้

ภาษาไทยสามารถเป็นอีกหนึ่งภาษาที่รองรับได้

## 8.7 Graceful Degradation

หากไม่มี Docker:

- ไม่แสดง Docker Widget ว่างเปล่า
- ไม่ทำให้ระบบหลัก Error
- แสดงสถานะ Integration ที่เหมาะสม

หากไม่มี AI Agent Integration:

- Developer Cockpit ส่วนอื่นยังต้องทำงานได้

หาก API ภายนอกใช้งานไม่ได้:

- แสดง Last Known Status พร้อม Timestamp
- แยกจาก Live Status
- ไม่แสดงข้อมูลเก่าเหมือนข้อมูลใหม่

---

# 9. Security & Privacy Requirements

## 9.1 Local-First

ข้อมูล Developer ส่วนใหญ่ควรประมวลผลภายในเครื่อง

การส่งข้อมูลออกไปต้องมีเหตุผลและความโปร่งใส

## 9.2 Secrets Handling

ห้าม:

- Log API Keys
- Log Access Tokens
- แสดง Password
- ส่ง `.env` ไปยัง AI โดยอัตโนมัติ
- ส่ง Environment Variables ทั้งหมดออกไป
- เก็บ Credential แบบ Plain Text โดยไม่มีมาตรการที่เหมาะสม

พิจารณา Keychain สำหรับ Credential ที่จำเป็น

## 9.3 Shell Command Safety

ระบบที่สั่ง Shell Command ต้องมี:

- Command Validation
- Argument Handling
- Working Directory Validation
- Execution Timeout
- Process Lifecycle Management
- Output Redaction
- Cancellation
- User Confirmation สำหรับคำสั่งเสี่ยง

อย่าประกอบ Shell Command ด้วย String Concatenation จาก Input ที่ไม่น่าเชื่อถือ

## 9.4 File System Access

ต้องจำกัดขอบเขตการอ่านไฟล์ตามความจำเป็น

ไม่ควร Scan ทั้ง Home Directory โดยไม่มีเหตุผล

ต้องระวัง:

- Symbolic Links
- File Permission
- Large Files
- File Changes ระหว่างอ่าน
- File Access Revocation
- Path Traversal

## 9.5 Network Security

หากมี External API:

- ใช้ HTTPS
- ตรวจสอบ TLS
- ใช้ Least Privilege
- รองรับ Rate Limit
- รองรับ Timeout
- จัดการ Retry อย่างเหมาะสม
- ไม่ Retry คำสั่งที่มีผลข้างเคียงโดยไม่ตรวจสอบ

---

# 10. Performance & Resource Budget

MyNotchApp เป็น Companion App ไม่ควรกลายเป็นโปรแกรมที่กินทรัพยากรจน Developer ต้องปิดมัน

เป้าหมายคือ:

- Low Idle CPU
- Low Memory Footprint
- Low Battery Impact
- Event-Driven Processing
- No Unnecessary Polling
- Fast UI Response

## 10.1 Monitoring Rules

ห้ามใช้ Polling ถี่เพียงเพื่อให้ข้อมูลดู Real-Time

พิจารณาใช้:

- File System Events
- Process Notifications
- Shell Hooks
- Native Notifications
- Explicit Integration Events

Polling ใช้ได้เมื่อไม่มี Event Source ที่เหมาะสม แต่ต้องมีเหตุผลและกำหนด Interval ตามความจำเป็น

## 10.2 Performance Measurement

ต้องวัด:

- Idle CPU
- Active CPU
- Memory Footprint
- Memory Growth
- Event Processing Latency
- UI Response Time
- Notification Delivery Latency
- Battery Impact
- GPU Usage

ไม่ควรกำหนดตัวเลข Budget แบบเดาสุ่มแล้วประกาศว่าผ่าน

ให้เริ่มจาก Baseline บนเครื่องทดสอบจริง จากนั้นกำหนด Budget ที่เหมาะสมกับ Hardware และ Use Case

ทุก Performance Optimization ต้องมี Measurement ก่อนและหลัง

---

# 11. Testing & Quality Assurance Protocol

ส่วนนี้เป็นข้อบังคับสำคัญที่สุดส่วนหนึ่งของเอกสาร

**การที่ Code Compile ผ่าน ไม่ได้แปลว่า Feature ทำงานถูกต้อง**

**การที่ Unit Test ผ่าน ไม่ได้แปลว่า Integration ทำงานได้จริง**

**การที่ UI แสดงผลได้ ไม่ได้แปลว่าผู้ใช้เข้าใจ**

## 11.1 Testing Layers

### Layer 1 — Static Validation

- Swift Compiler
- Type Checking
- Linting เมื่อมีการตั้งค่า
- Dependency Validation
- Build Configuration Validation

### Layer 2 — Unit Testing

ทดสอบ:

- Reducer
- State Transition
- Event Normalization
- Parsing
- Deduplication
- Correlation
- Priority
- Error Mapping
- Permission Logic

### Layer 3 — Integration Testing

ทดสอบ:

- Shell Hook → Event Bus
- Event Bus → Store
- Store → Reducer
- Reducer → UI State
- Build Adapter → Event
- Test Adapter → Event
- Process Monitor → Event
- Docker Adapter → Event

### Layer 4 — End-to-End Testing

ทดสอบ Workflow จริง:

1. เปิดโปรเจกต์
2. สั่ง Build
3. ตรวจสอบสถานะ
4. ทำให้เกิด Build Failure
5. ตรวจสอบ Error
6. เปิดไฟล์ที่ผิดพลาด
7. แก้ไข
8. Build อีกครั้ง
9. ตรวจสอบ Success

ต้องมีทั้ง Happy Path และ Failure Path

### Layer 5 — Manual macOS Testing

ตรวจสอบ:

- Notch Interaction
- Hover
- Click
- Gesture
- Window Lifecycle
- Focus
- Multi-Display เมื่อเกี่ยวข้อง
- Sleep / Wake
- App Relaunch
- Permission Changes
- Dark / Light Mode
- Accessibility

### Layer 6 — Usability Testing

ทดสอบกับผู้ใช้จริงอย่างน้อย 3–5 คนในรอบแรก

ควรมี Developer ที่มีประสบการณ์แตกต่างกัน

ไม่ควรอธิบาย UI ก่อนให้ทดลอง เพราะต้องการวัดว่าผู้ใช้เข้าใจได้เองหรือไม่

วัด:

- เข้าใจสถานะหรือไม่
- ใช้เวลาเท่าใดในการเข้าใจ
- รู้หรือไม่ว่าควรกดอะไร
- เข้าใจคำศัพท์หรือไม่
- มีจุดไหนที่ทำให้สับสน
- Notification รบกวนหรือไม่
- Feature ช่วยลดขั้นตอนจริงหรือไม่

## 11.2 Test Scenario Matrix

ทุก Feature ต้องมี Test Scenario อย่างน้อย:

| Scenario | Expected Behavior |
|---|---|
| Normal Operation | ทำงานปกติ |
| Failure | แสดง Failure ถูกต้อง |
| Unknown State | ไม่เดาสถานะ |
| Permission Denied | แสดงข้อจำกัด |
| Source Unavailable | ไม่ทำให้ระบบหลักล้ม |
| Malformed Input | จัดการอย่างปลอดภัย |
| Duplicate Event | ไม่แจ้งซ้ำ |
| Rapid Events | ไม่ทำให้ UI ค้าง |
| Process Terminated | ปรับสถานะถูกต้อง |
| App Restart | กู้ State เท่าที่ออกแบบไว้ |
| Large Input | ไม่ทำให้ Memory พุ่งผิดปกติ |
| Concurrent Events | ไม่มี Race Condition ที่ทำให้ข้อมูลผิด |

## 11.3 Evidence-Based Testing

ทุกการรายงานผลต้องมีหลักฐาน

ตัวอย่าง:

**ไม่เพียงพอ:**

> Tests passed. Everything works.

**รูปแบบที่ต้องการ:**

```text
Test Run Summary

Command:
swift test

Result:
Passed: 42
Failed: 0
Skipped: 1

Duration:
12.4 seconds

Evidence:
- Test target: MyNotchAppTests
- Test suites discovered: 8
- Process exit code: 0

Limitations:
- Manual Notch Interaction was not tested.
- Docker Integration was not tested.
- macOS Permission Recovery was not tested.
```

ตัวเลขทั้งหมดในตัวอย่างเป็นข้อมูลสมมติสำหรับแสดงรูปแบบรายงาน ห้ามนำไปใช้เป็นผลทดสอบจริง

## 11.4 No False Pass

ห้าม:

- เปลี่ยน Test ให้ไม่ตรวจสอบสิ่งสำคัญ
- ลบ Test ที่ Fail เพื่อให้ผ่าน
- Mock ระบบทั้งหมดแล้วอ้างว่า Integration ผ่าน
- ใช้ Cached Result แทนการรันจริง
- รายงานจำนวน Test จากความจำ
- ซ่อน Warning หรือ Failure
- เปลี่ยน Expected Result โดยไม่มีเหตุผล
- รายงาน Build Success เมื่อคำสั่งยังทำงานไม่จบ

หาก Test ไม่สามารถรันได้ ต้องรายงานว่า Not Run พร้อมสาเหตุ

หาก Test ผ่านเฉพาะ Mock ต้องรายงานว่า Mock Test ไม่ใช่ Real Integration Test

หากไม่มีเครื่องหรือ Environment สำหรับทดสอบ ให้ระบุข้อจำกัดอย่างตรงไปตรงมา

---

# 12. AI Coding Agent Execution Protocol

ส่วนนี้เป็นกฎการทำงานของ AI Coding Agent ทุกตัวที่เข้ามาพัฒนา MyNotchApp

## 12.1 Before Coding

ก่อนแก้ไขโค้ด ต้อง:

1. อ่าน Repository Structure
2. อ่านไฟล์ที่เกี่ยวข้อง
3. เข้าใจ Data Flow
4. เข้าใจ State Flow
5. เข้าใจ Existing Tests
6. ตรวจสอบ Dependency
7. ตรวจสอบ API ที่ใช้อยู่
8. ระบุผลกระทบที่อาจเกิดขึ้น
9. ระบุสิ่งที่ยังไม่ทราบ
10. สร้าง Implementation Plan

ห้ามเริ่มแก้ไขทันทีเพียงเพราะเข้าใจชื่อ Feature

## 12.2 Investigation First

เมื่อพบ Bug:

1. ทำซ้ำ Bug
2. ตรวจสอบ Log
3. ตรวจสอบ Stack Trace
4. ตรวจสอบ State
5. ตรวจสอบ Event Sequence
6. ตรวจสอบ Lifecycle
7. ระบุ Root Cause
8. เสนอแนวทางแก้ไข
9. ทดสอบก่อนและหลังแก้ไข

ห้ามแก้จากอาการโดยไม่ตรวจสอบต้นเหตุ หากยังไม่มีหลักฐานเพียงพอ

## 12.3 Implementation Strategy

แบ่งงานเป็น Small Changes

หนึ่ง Change ควรมีขอบเขตที่เข้าใจได้

หลังแก้ไขแต่ละส่วน:

- Build
- Run Relevant Tests
- Review Diff
- ตรวจสอบ Side Effects
- ตรวจสอบ Logs

อย่ารอให้แก้ไขไฟล์จำนวนมากแล้วค่อยทดสอบทั้งหมด

## 12.4 Stop Conditions

AI ต้องหยุดและรายงานก่อนดำเนินการต่อเมื่อ:

- พบ Architecture Conflict
- พบข้อมูลที่ขัดแย้งกับเอกสาร
- พบ API ที่ไม่แน่ใจว่าใช้ได้
- พบ Permission ที่จำเป็นแต่ไม่มีสิทธิ์
- พบ Security Risk
- พบ Destructive Operation
- พบ Test Baseline ที่เปลี่ยนไปอย่างไม่คาดคิด
- พบ Regression ที่กระทบระบบเดิม
- พบข้อจำกัดของ macOS ที่ต้องตัดสินใจเชิงผลิตภัณฑ์

ห้ามตัดสินใจแทนเจ้าของโปรเจกต์ในเรื่องที่มีผลต่อ Product Direction, Privacy หรือความเสี่ยงสูง

## 12.5 Required Work Report

ทุกงานที่ทำเสร็จต้องสรุป:

```text
TASK:
สิ่งที่ได้รับมอบหมาย

INVESTIGATION:
สิ่งที่ตรวจสอบก่อนเริ่ม

ROOT CAUSE:
สาเหตุที่พบ หรือเหตุผลที่ไม่มี Bug

CHANGES:
ไฟล์และระบบที่แก้ไข

DESIGN DECISIONS:
เหตุผลของการเลือกแนวทาง

TESTS:
คำสั่งที่รันจริง

RESULTS:
ผลลัพธ์จริง

LIMITATIONS:
สิ่งที่ยังไม่ได้ทดสอบหรือยังไม่รองรับ

RISKS:
ความเสี่ยงที่ยังเหลือ

USER IMPACT:
ผู้ใช้ได้รับประโยชน์อย่างไร

NEXT STEP:
ขั้นตอนที่แนะนำต่อไป
```

## 12.6 Documentation Maintenance

ทุก Feature ใหม่ควรปรับปรุงเอกสารที่เกี่ยวข้อง:

- Architecture
- Feature Specification
- Integration Guide
- Testing Guide
- User Guide
- Known Limitations

ห้ามเขียน Documentation ที่อธิบายพฤติกรรมที่โค้ดยังไม่ได้ทำจริง

---

# 13. Definition of Done

Feature จะถือว่าเสร็จเมื่อผ่านเกณฑ์ที่เกี่ยวข้องทั้งหมด

## Product Quality

- แก้ปัญหาจริง
- มีประโยชน์ต่อผู้ใช้
- ไม่เพิ่มความซับซ้อนโดยไม่จำเป็น
- ใช้ภาษาที่เข้าใจง่าย
- ไม่รบกวน Workflow

## Engineering Quality

- Architecture สอดคล้องกับระบบเดิม
- ไม่มีการเพิ่ม Dependency โดยไม่จำเป็น
- Error Handling ถูกต้อง
- Concurrency ปลอดภัย
- Resource Management เหมาะสม
- มี Logging ที่ไม่เปิดเผยข้อมูลสำคัญ

## UX Quality

- เข้าใจได้โดยไม่ต้องอ่าน Documentation
- Action มีความหมายชัดเจน
- ไม่มีข้อมูลเกินความจำเป็น
- รองรับสถานะ Unknown
- ไม่มี UI ที่แสดงข้อมูลผิด
- รองรับ Accessibility ตามขอบเขตที่กำหนด

## Testing Quality

- Build ผ่านจริง
- Unit Tests ผ่าน
- Integration Tests ผ่านตาม Scope
- Failure Scenarios ถูกทดสอบ
- ไม่มี Test ที่ถูกปิดเพื่อทำให้ผ่าน
- รายงานข้อจำกัดครบถ้วน

## Security Quality

- ไม่มี Secret Leakage
- ไม่มี Automatic Destructive Action
- Permission ถูกจำกัดตามความจำเป็น
- External Data ถูกตรวจสอบ
- Logs ผ่านการ Redact

## User Value

ต้องตอบให้ได้ว่า:

1. ก่อนมีฟีเจอร์ ผู้ใช้ต้องทำอะไร?
2. หลังมีฟีเจอร์ ผู้ใช้ทำอะไรน้อยลง?
3. ลดเวลาได้จริงหรือไม่?
4. ลดความผิดพลาดได้จริงหรือไม่?
5. ผู้ใช้เข้าใจข้อมูลได้เร็วขึ้นหรือไม่?
6. มีหลักฐานจากการทดสอบหรือ Feedback หรือไม่?

หากตอบไม่ได้ ให้ถือว่ายังไม่สามารถยืนยันคุณค่าของ Feature ได้

---

# 14. Product Metrics

อย่าวัดความสำเร็จจากจำนวน Feature หรือจำนวนบรรทัดโค้ด

ให้วัดจากประโยชน์จริง

## 14.1 Usability Metrics

- Time to Understand
- Time to Action
- Task Completion Rate
- Misinterpretation Rate
- Number of Unnecessary Clicks
- User Confidence

## 14.2 Reliability Metrics

- False Positive Rate
- False Negative Rate เมื่อสามารถวัดได้
- Event Processing Failure
- Duplicate Notification Rate
- Integration Failure Rate
- Crash Rate
- Recovery Time

## 14.3 Performance Metrics

- Idle CPU
- Active CPU
- Memory Footprint
- Memory Growth
- Battery Impact
- Event Latency
- UI Responsiveness

## 14.4 Product Value Metrics

- จำนวนขั้นตอนที่ลดลง
- เวลาที่ประหยัดได้
- จำนวนครั้งที่ผู้ใช้ต้องสลับหน้าต่างลดลง
- จำนวน Error ที่ผู้ใช้ตรวจพบเร็วขึ้น
- ความถี่ในการใช้งานจริง
- Feedback จาก Developer

ต้องเก็บข้อมูลเท่าที่จำเป็น และต้องเคารพ Privacy

ห้ามเพิ่ม Telemetry เพียงเพื่อให้มีตัวเลขสวย ๆ

---

# 15. Recommended Development Priority

ลำดับนี้เป็นข้อเสนอเบื้องต้น ต้องปรับหลัง Repository Audit

| Priority | Feature | Reason |
|---|---|---|
| P0 | Repository Audit | เข้าใจระบบเดิม |
| P0 | Build & Test Intelligence | ประโยชน์ชัดเจน |
| P0 | Agent Conflict Detection | ลดปัญหาการทำงานร่วมกับ AI |
| P0 | Port & Process Intelligence | แก้ปัญหาที่เกิดขึ้นบ่อย |
| P0 | Change Impact Intelligence | ช่วยลดการมองข้ามผลกระทบ |
| P1 | Service Health & Docker | ช่วยดูแล Local Environment |
| P1 | CI/CD Watchtower | ช่วยติดตาม Pipeline |
| P1 | Database Intelligence | ช่วยตรวจสอบ Migration |
| P1 | Security Watcher | ช่วยติดตาม Dependencies |
| P1 | API & Environment Guard | ลดปัญหาการตั้งค่า |
| P2 | Release Readiness | รวมสถานะก่อน Release |
| Separate | Lock Screen / Face ID | ต้องประเมิน Distribution Risk |
| Separate | Advanced Visual Effects | ต้องประเมิน Performance |

อย่าพัฒนา P0 ทั้งหมดพร้อมกัน

ควรเริ่มจาก Feature เดียว ทำให้สมบูรณ์ วัดผล และเรียนรู้ก่อน

---

# 16. Suggested Documentation Structure

โครงสร้างเอกสารที่เสนอ:

```text
docs/
|
+-- product/
|   +-- PRODUCT_VISION.md
|   +-- TARGET_USERS.md
|   +-- UX_PRINCIPLES.md
|   +-- PRODUCT_ROADMAP.md
|   +-- FEATURE_STATUS.md
|
+-- architecture/
|   +-- SYSTEM_OVERVIEW.md
|   +-- EVENT_ARCHITECTURE.md
|   +-- STATE_MANAGEMENT.md
|   +-- INTEGRATION_ARCHITECTURE.md
|   +-- SECURITY_MODEL.md
|
+-- features/
|   +-- BUILD_TEST_INTELLIGENCE.md
|   +-- AGENT_CONFLICT_DETECTION.md
|   +-- PROCESS_INTELLIGENCE.md
|   +-- CHANGE_IMPACT_INTELLIGENCE.md
|   +-- SERVICE_HEALTH.md
|
+-- quality/
|   +-- TESTING_STRATEGY.md
|   +-- TEST_BASELINE.md
|   +-- PERFORMANCE_BUDGET.md
|   +-- RELEASE_CHECKLIST.md
|
+-- audit/
|   +-- REPOSITORY_AUDIT.md
|   +-- ARCHITECTURE_AUDIT.md
|   +-- RISK_REGISTER.md
|
+-- development/
    +-- AI_AGENT_PROTOCOL.md
    +-- CONTRIBUTING.md
    +-- DEVELOPMENT_SETUP.md
```

ไม่จำเป็นต้องสร้างไฟล์ทั้งหมดทันที

ให้สร้างตามความต้องการจริง และหลีกเลี่ยงเอกสารซ้ำซ้อน

---

# 17. First Execution Plan — What AI Must Do First

เมื่อได้รับเอกสารนี้ ห้ามเริ่มพัฒนา Feature ใหม่ทันที

ให้ทำงานตามลำดับ:

## Step 1 — Understand

อ่านเอกสารนี้ให้ครบ

ตรวจสอบ Repository จริง

ห้ามใช้ข้อมูลในเอกสารแทนการตรวจสอบโค้ด

## Step 2 — Audit

จัดทำ:

- Repository Audit
- Architecture Audit
- Feature Status
- Test Baseline
- Risk Register

## Step 3 — Compare

เปรียบเทียบ:

- Current Implementation
- Proposed Architecture
- Product Requirements
- Testing Capability
- Security Constraints

ระบุสิ่งที่:

- สอดคล้องกัน
- ขัดแย้งกัน
- ยังไม่ชัดเจน
- ไม่จำเป็น
- มีความเสี่ยง

## Step 4 — Recommend

เสนอแผนพัฒนาที่ปรับตามสภาพ Repository จริง

ต้องมี:

- เหตุผล
- Scope
- Dependencies
- Risks
- Acceptance Criteria
- Testing Strategy
- Estimated Complexity

หากประเมินเวลาไม่ได้ ให้ใช้ระดับความซับซ้อนแทนการเดาเวลา

## Step 5 — Wait for Approval

ก่อนเริ่ม Implementation ต้องนำเสนอผล Audit และแผนงานให้เจ้าของโปรเจกต์พิจารณา

ห้ามเริ่มสร้าง Feature ขนาดใหญ่โดยอัตโนมัติ

---

# 18. Critical Product Decisions That Must Not Be Assumed

เรื่องเหล่านี้ต้องตรวจสอบหรือขอการตัดสินใจจากเจ้าของโปรเจกต์

1. macOS Minimum Deployment Target
2. Supported macOS Versions
3. Distribution Channel
4. Developer ID Signing
5. Notarization Strategy
6. App Sandbox Strategy
7. Privacy Policy
8. External AI Provider
9. Local-Only vs Cloud AI
10. Supported Agent Integrations
11. Supported Build Systems
12. Supported Docker Environments
13. Telemetry Policy
14. Crash Reporting
15. Open Source vs Closed Source
16. Plugin Architecture
17. Experimental Feature Policy
18. Compatibility Promise

อย่าตัดสินใจเรื่องเหล่านี้ด้วยการเดา

---

# 19. Final Product Standard

MyNotchApp ต้องไม่เป็นแอปที่มี Feature มากแต่ผู้ใช้ไม่เข้าใจ

ต้องเป็นแอปที่ผู้ใช้เปิดขึ้นมาแล้วรู้สึกว่า:

- มันรู้ว่าอะไรสำคัญ
- มันไม่รบกวนฉัน
- มันไม่ได้สร้างข้อมูลขึ้นมาเอง
- ฉันเชื่อถือสถานะที่มันแสดงได้
- ฉันเข้าใจว่าต้องทำอะไรต่อ
- ฉันใช้มันแล้วทำงานสะดวกขึ้นจริง

Developer ที่เพิ่งเริ่มต้นควรเข้าใจข้อความพื้นฐานได้

Developer ที่มีประสบการณ์ควรเข้าถึงรายละเอียดเชิงเทคนิคได้

ทั้งสองกลุ่มควรใช้แอปเดียวกันได้โดยไม่ต้องถูกบังคับให้ใช้ Interface ที่ไม่เหมาะกับตนเอง

## สิ่งที่เราไม่ต้องการ

- Dashboard ที่เต็มไปด้วยตัวเลข
- UI ที่ดูเหมือน AI สร้าง
- Notification ที่ไม่จำเป็น
- Animation ที่ทำให้ระบบหนัก
- Feature ที่ไม่มี Use Case
- Architecture ที่ซับซ้อนเกินความจำเป็น
- AI ที่เดาแทนข้อมูลจริง
- Test ที่ผ่านเพราะถูกทำให้ง่ายลง
- Documentation ที่ไม่ตรงกับโค้ด
- คำกล่าวอ้างว่าเสร็จทั้งที่ยังไม่เคยทดสอบกับผู้ใช้จริง

## สิ่งที่เราต้องการ

- Simple
- Native
- Reliable
- Understandable
- Actionable
- Efficient
- Secure
- Maintainable
- Extensible
- Honest

---

# 20. Final Instruction to All AI Agents

คุณมีหน้าที่ช่วยเจ้าของโปรเจกต์สร้างผลิตภัณฑ์ที่ดีขึ้น ไม่ใช่ทำตามเอกสารอย่างไม่มีวิจารณญาณ

เอกสารนี้เป็น Product Direction และ Engineering Baseline ไม่ใช่คำสั่งให้สร้างทุกอย่างตามตัวอักษรโดยไม่ตรวจสอบความเหมาะสม

หากพบว่าแนวคิดใดไม่เหมาะกับ Architecture จริง มีข้อจำกัดของ macOS หรือสร้างภาระให้ผู้ใช้มากกว่าประโยชน์ คุณต้องอธิบายเหตุผลและเสนอทางเลือก

หากพบว่า Feature ใดไม่ควรสร้าง ให้กล้าบอกว่าไม่ควรสร้าง

หากพบว่าระบบเดิมดีอยู่แล้ว อย่าแก้เพียงเพื่อให้โค้ดดูใหม่

หากพบว่าข้อมูลไม่เพียงพอ ให้หยุดตรวจสอบเพิ่มเติม

หาก Test ไม่ผ่าน ให้รายงานว่าไม่ผ่าน

หากยังไม่ได้ทดสอบ ให้รายงานว่ายังไม่ได้ทดสอบ

หากผ่านเฉพาะบางส่วน ให้ระบุว่าผ่านเฉพาะส่วนใด

ห้ามใช้คำว่า Complete, Fully Working, Production Ready หรือ Tested Successfully โดยไม่มีหลักฐานรองรับ

**เป้าหมายสุดท้ายไม่ใช่การทำให้ MyNotchApp ดูเหมือนมีความสามารถมากมาย แต่คือการทำให้ Developer สามารถทำงานได้สะดวกขึ้นจริง โดยไม่ต้องเสียเวลาเรียนรู้แอปอีกตัวหนึ่งมากเกินไป**

> Build for developers. Respect their workflow. Show only what matters. Never pretend something works when it does not.
