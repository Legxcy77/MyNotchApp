import Foundation
import Testing
@testable import NotchKit

@Suite struct WorklogAndTerminalTests {
    @Test func dailyWorklogPersistsByDayLoadsRangesAndClearsOnlyTargetDay() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotchWorklogTest-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = DailyWorklogStore(directory: tempDir)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let today = calendar.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 10, minute: 30))!
        let yesterday = calendar.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 18, minute: 15))!
        let tenDaysAgo = calendar.date(from: DateComponents(year: 2026, month: 11, day: 6, hour: 9, minute: 0))!
        let lastYear = calendar.date(from: DateComponents(year: 2025, month: 11, day: 16, hour: 12, minute: 0))!

        store.append(WorklogEntry(timestamp: today, kind: .buildPassed, title: "MyNotchApp built", detail: "swift build"), calendar: calendar)
        store.append(WorklogEntry(timestamp: today, kind: .agentWaiting, title: "Waiting for Approval", detail: "swift test"), calendar: calendar)
        store.append(WorklogEntry(timestamp: yesterday, kind: .devServerReady, title: "Vite :5173", detail: "npm run dev"), calendar: calendar)
        store.append(WorklogEntry(timestamp: tenDaysAgo, kind: .buildFailed, title: "API failed", detail: "CS0103"), calendar: calendar)
        store.append(WorklogEntry(timestamp: lastYear, kind: .command, title: "Old deploy", detail: "release"), calendar: calendar)

        #expect(store.load(range: .today, relativeTo: today, calendar: calendar).count == 2)
        #expect(store.load(range: .yesterday, relativeTo: today, calendar: calendar).count == 1)
        #expect(store.load(range: .last7Days, relativeTo: today, calendar: calendar).count == 3)
        #expect(store.load(range: .last30Days, relativeTo: today, calendar: calendar).count == 4)
        #expect(store.load(range: .lastYear, relativeTo: today, calendar: calendar).count == 5)

        // Updating AI Thai explanation persists on disk
        let entries = store.load(range: .today, relativeTo: today, calendar: calendar)
        let target = try #require(entries.first)
        store.updateAIExplanation(entryID: target.id, on: today, explanation: "ขาด symbol ใน scope ให้ตรวจสอบ import", calendar: calendar)
        let updated = store.load(range: .today, relativeTo: today, calendar: calendar).first { $0.id == target.id }
        #expect(updated?.aiExplanation == "ขาด symbol ใน scope ให้ตรวจสอบ import")

        // Clearing today keeps yesterday & older days intact
        store.clear(dayKey: DailyWorklogStore.dayKey(for: today, calendar: calendar))
        #expect(store.load(range: .today, relativeTo: today, calendar: calendar).isEmpty)
        #expect(store.load(range: .yesterday, relativeTo: today, calendar: calendar).count == 1)
    }

    @Test func terminalOutputParserHandlesNpmViteNextDotnetAndPortConflicts() {
        let viteOutput = """
          VITE v6.0.1  ready in 230 ms
          ➜  Local:   http://localhost:5173/
        """
        let viteParsed = TerminalOutputParser.parse(command: "npm run dev", output: viteOutput, exitCode: nil)
        #expect(viteParsed.kind == .serverReady(port: 5173, url: "http://localhost:5173/"))

        let eaddrOutput = "Error: listen EADDRINUSE: address already in use :::3000"
        let eaddrParsed = TerminalOutputParser.parse(command: "npm run dev", output: eaddrOutput, exitCode: 1)
        #expect(eaddrParsed.kind == .error(category: "Port In Use", summary: "Port 3000 ถูกใช้งานอยู่แล้ว (EADDRINUSE)", location: nil))

        let dotnetOutput = "info: Microsoft.Hosting.Lifetime[14]\n      Now listening on: https://localhost:7001"
        let dotnetParsed = TerminalOutputParser.parse(command: "dotnet run", output: dotnetOutput, exitCode: nil)
        #expect(dotnetParsed.kind == .serverReady(port: 7001, url: "https://localhost:7001"))

        let moduleOutput = "Error: Cannot find module '@acme/ui' in /app/src/index.ts:14:2"
        let moduleParsed = TerminalOutputParser.parse(command: "npm run dev", output: moduleOutput, exitCode: 1)
        if case .error(let category, let summary, _) = moduleParsed.kind {
            #expect(category == "Missing Module")
            #expect(summary.contains("@acme/ui"))
        } else {
            Issue.record("Expected error for missing module")
        }
    }

    @Test func secretRedactorMasksTokensAndPasswordsBeforeAISend() {
        let raw = """
        Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.secret.sig
        GEMINI_API_KEY=AIzaSyD1234567890abcdef
        DATABASE_URL=postgres://user:supersecret@localhost:5432/db
        """
        let clean = ErrorRedactor.redact(raw)
        #expect(!clean.contains("eyJhbGciOiJIUzI1NiJ9"))
        #expect(!clean.contains("AIzaSyD1234567890abcdef"))
        #expect(!clean.contains("supersecret"))
        #expect(clean.contains("[REDACTED]"))
    }
}

