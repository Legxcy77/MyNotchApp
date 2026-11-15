import Foundation
import Testing
@testable import NotchKit

@Suite("NotesAndAndroidDropTests")
struct NotesAndAndroidDropTests {
    @Test func reducerHandlesNotesTasksAndClipboardPause() {
        var state = NotchState()

        _ = NotchReducer.reduce(&state, .setQuickNote("Buy coffee"))
        #expect(state.notesPayload.note == "Buy coffee")

        _ = NotchReducer.reduce(&state, .addQuickTask("Ship release"))
        #expect(state.notesPayload.tasks.count == 1)
        let id = state.notesPayload.tasks[0].id

        _ = NotchReducer.reduce(&state, .toggleQuickTask(id))
        #expect(state.notesPayload.tasks[0].isDone == true)

        _ = NotchReducer.reduce(&state, .removeQuickTask(id))
        #expect(state.notesPayload.tasks.isEmpty)

        _ = NotchReducer.reduce(&state, .toggleClipboardPaused)
        #expect(state.isClipboardPaused == true)

        _ = NotchReducer.reduce(&state, .clipboardRecorded(.text("ignored"), at: .now))
        #expect(state.clipboard.items.isEmpty)
    }

    @Test func extractsMultipartUploadedFilesAndRendersHTML() {
        let boundary = "----NotchTestBoundary"
        let multipart = """
        --\(boundary)\r
        Content-Disposition: form-data; name="file"; filename="hello.txt"\r
        Content-Type: text/plain\r
        \r
        Hello Android\r
        --\(boundary)--\r
        """
        let extracted = AndroidDropHTML.extractMultipartFiles(
            body: Data(multipart.utf8),
            contentType: "multipart/form-data; boundary=\(boundary)"
        )
        #expect(extracted.count == 1)
        #expect(extracted[0].filename == "hello.txt")
        #expect(String(data: extracted[0].data, encoding: .utf8) == "Hello Android")

        let html = AndroidDropHTML.renderPage(files: [URL(fileURLWithPath: "/tmp/demo.apk")])
        #expect(html.contains("demo.apk"))
        #expect(html.contains("/download/0"))
    }
}
