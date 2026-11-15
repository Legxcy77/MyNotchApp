import CoreImage
import Darwin
import Foundation
import Network

public struct AndroidDropStatus: Equatable, Sendable {
    public var isRunning: Bool
    public var urlString: String?
    public var qrPNGData: Data?
    public var receivedCount: Int

    public init(
        isRunning: Bool = false,
        urlString: String? = nil,
        qrPNGData: Data? = nil,
        receivedCount: Int = 0
    ) {
        self.isRunning = isRunning
        self.urlString = urlString
        self.qrPNGData = qrPNGData
        self.receivedCount = receivedCount
    }
}

public enum AndroidDropHTML {
    public static func renderPage(files: [URL]) -> String {
        let fileListHTML: String
        if files.isEmpty {
            fileListHTML = "<p class=\"muted\">No files staged on Mac right now. Drag files into the Notch to share them here.</p>"
        } else {
            let items = files.enumerated().map { idx, url in
                let name = url.lastPathComponent
                    .replacingOccurrences(of: "&", with: "&amp;")
                    .replacingOccurrences(of: "<", with: "&lt;")
                return "<a class=\"file\" href=\"/download/\(idx)\"><span>\(name)</span><span class=\"badge\">Download</span></a>"
            }.joined(separator: "\n")
            fileListHTML = items
        }

        return """
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <title>MyNotchApp Drop</title>
        <style>
          body{margin:0;background:#0b0b0e;color:#f5f5f7;font-family:-apple-system,system-ui,sans-serif;padding:20px}
          .card{background:#18181d;border-radius:16px;padding:16px;margin-bottom:16px}
          h1{font-size:20px;margin:0 0 12px}
          h2{font-size:14px;text-transform:uppercase;letter-spacing:.06em;color:#8e8e93;margin:0 0 10px}
          .muted{color:#8e8e93;font-size:14px;margin:0}
          .file{display:flex;justify-content:space-between;align-items:center;padding:12px;background:#24242b;border-radius:12px;color:#fff;text-decoration:none;margin-bottom:8px;font-size:14px}
          .badge{background:#0a84ff;padding:4px 10px;border-radius:999px;font-size:12px;font-weight:600}
          input[type=file]{width:100%;margin:8px 0 12px;color:#ccc}
          button{width:100%;padding:14px;border:0;border-radius:12px;background:#30d158;color:#000;font-weight:700;font-size:15px}
          #status{margin-top:10px;font-size:13px;color:#30d158}
        </style>
        </head>
        <body>
          <h1>MyNotchApp Drop</h1>
          <div class="card">
            <h2>Send from Android to Mac</h2>
            <input id="picker" type="file" multiple>
            <button onclick="uploadFiles()">Upload to Mac</button>
            <div id="status"></div>
          </div>
          <div class="card">
            <h2>Download from Mac</h2>
            \(fileListHTML)
          </div>
          <script>
          async function uploadFiles(){
            const input = document.getElementById('picker');
            const st = document.getElementById('status');
            if(!input.files.length){ st.textContent='Pick at least one file first.'; return; }
            st.textContent='Uploading...';
            const fd = new FormData();
            for(const f of input.files){ fd.append('file', f, f.name); }
            const res = await fetch('/upload', { method:'POST', body: fd });
            st.textContent = res.ok ? 'Sent ' + input.files.length + ' file(s) to Mac!' : 'Upload failed.';
          }
          </script>
        </body>
        </html>
        """
    }

    public static func extractMultipartFiles(body: Data, contentType: String) -> [(filename: String, data: Data)] {
        guard let range = contentType.range(of: "boundary=") else { return [] }
        var boundary = String(contentType[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if boundary.hasPrefix("\""), boundary.hasSuffix("\""), boundary.count >= 2 {
            boundary = String(boundary.dropFirst().dropLast())
        }
        guard let boundaryData = "--\(boundary)".data(using: .utf8),
              let headerSep = Data("\r\n\r\n".utf8) as Data? else { return [] }

        var results: [(String, Data)] = []
        var searchStart = body.startIndex
        while let bRange = body.range(of: boundaryData, in: searchStart..<body.endIndex) {
            let partStart = bRange.upperBound
            guard let nextRange = body.range(of: boundaryData, in: partStart..<body.endIndex) else { break }
            let partSlice = body[partStart..<nextRange.lowerBound]
            if let sepRange = partSlice.range(of: headerSep) {
                let headerData = partSlice[partSlice.startIndex..<sepRange.lowerBound]
                var fileData = Data(partSlice[sepRange.upperBound..<partSlice.endIndex])
                if fileData.suffix(2) == Data("\r\n".utf8) {
                    fileData.removeLast(2)
                }
                if let headerStr = String(data: headerData, encoding: .utf8),
                   let fnRange = headerStr.range(of: "filename=\"") {
                    let after = headerStr[fnRange.upperBound...]
                    if let endQuote = after.firstIndex(of: "\"") {
                        let rawName = String(after[..<endQuote])
                        let safeName = (rawName as NSString).lastPathComponent
                        if !safeName.isEmpty {
                            results.append((safeName, fileData))
                        }
                    }
                }
            }
            searchStart = nextRange.lowerBound
        }
        return results
    }
}

@MainActor
public final class AndroidDropServer {
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.pawalit.MyNotchApp.androidDrop")
    private var stagedFilesSnapshot: [URL] = []
    private let onStatusChange: @MainActor (AndroidDropStatus) -> Void
    private let onFilesReceived: @MainActor ([URL]) -> Void
    private var receivedCount = 0

    public init(
        onStatusChange: @escaping @MainActor (AndroidDropStatus) -> Void,
        onFilesReceived: @escaping @MainActor ([URL]) -> Void
    ) {
        self.onStatusChange = onStatusChange
        self.onFilesReceived = onFilesReceived
    }

    public func updateStagedFiles(_ files: [URL]) {
        stagedFilesSnapshot = files
    }

    public func start() {
        guard listener == nil else { return }
        do {
            let params = NWParameters.tcp
            let nwListener = try NWListener(using: params, on: .any)
            nwListener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    switch state {
                    case .ready:
                        if let port = nwListener.port?.rawValue, let ip = Self.localWiFiIPv4() {
                            let url = "http://\(ip):\(port)"
                            let qr = Self.qrPNG(for: url)
                            self.onStatusChange(AndroidDropStatus(
                                isRunning: true,
                                urlString: url,
                                qrPNGData: qr,
                                receivedCount: self.receivedCount
                            ))
                        }
                    case .failed, .cancelled:
                        self.onStatusChange(AndroidDropStatus())
                    default:
                        break
                    }
                }
            }
            nwListener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor [weak self] in
                    guard let self else {
                        connection.cancel()
                        return
                    }
                    let files = self.stagedFilesSnapshot
                    let callback = self.onFilesReceived
                    let incrementCount: @Sendable (Int) -> Void = { [weak self] added in
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            self.receivedCount += added
                            if let url = nwListener.port?.rawValue, let ip = Self.localWiFiIPv4() {
                                let urlStr = "http://\(ip):\(url)"
                                self.onStatusChange(AndroidDropStatus(
                                    isRunning: true,
                                    urlString: urlStr,
                                    qrPNGData: Self.qrPNG(for: urlStr),
                                    receivedCount: self.receivedCount
                                ))
                            }
                        }
                    }
                    self.queue.async {
                        Self.handleConnection(
                            connection,
                            stagedFiles: files,
                            onSaved: { urls in
                                incrementCount(urls.count)
                                Task { @MainActor in callback(urls) }
                            }
                        )
                    }
                }
            }
            nwListener.start(queue: queue)
            self.listener = nwListener
        } catch {
            onStatusChange(AndroidDropStatus())
        }
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        onStatusChange(AndroidDropStatus())
    }

    private nonisolated static func handleConnection(
        _ connection: NWConnection,
        stagedFiles: [URL],
        onSaved: @escaping @Sendable ([URL]) -> Void
    ) {
        connection.start(queue: DispatchQueue.global(qos: .userInitiated))
        receiveStep(connection: connection, buffer: Data(), stagedFiles: stagedFiles, onSaved: onSaved)
    }

    private nonisolated static func receiveStep(
        connection: NWConnection,
        buffer: Data,
        stagedFiles: [URL],
        onSaved: @escaping @Sendable ([URL]) -> Void
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 256 * 1024) { data, _, isComplete, error in
            var nextBuffer = buffer
            if let data { nextBuffer.append(data) }
            if error != nil {
                connection.cancel()
                return
            }
            if let headerEnd = nextBuffer.range(of: Data("\r\n\r\n".utf8)) {
                let headerStr = String(data: nextBuffer[..<headerEnd.lowerBound], encoding: .utf8) ?? ""
                let contentLength = parseContentLength(headerStr)
                let bodyStart = headerEnd.upperBound
                let currentBodyLen = nextBuffer.count - bodyStart
                if currentBodyLen >= contentLength || isComplete {
                    let bodyData = Data(nextBuffer[bodyStart..<min(nextBuffer.count, bodyStart + contentLength)])
                    respond(
                        connection: connection,
                        header: headerStr,
                        body: bodyData,
                        stagedFiles: stagedFiles,
                        onSaved: onSaved
                    )
                    return
                }
            } else if isComplete {
                connection.cancel()
                return
            }
            receiveStep(connection: connection, buffer: nextBuffer, stagedFiles: stagedFiles, onSaved: onSaved)
        }
    }

    private nonisolated static func parseContentLength(_ header: String) -> Int {
        for line in header.split(separator: "\r\n") {
            let lower = line.lowercased()
            if lower.hasPrefix("content-length:"),
               let val = Int(line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)) {
                return val
            }
        }
        return 0
    }

    private nonisolated static func parseContentType(_ header: String) -> String {
        for line in header.split(separator: "\r\n") {
            let lower = line.lowercased()
            if lower.hasPrefix("content-type:") {
                return String(line.dropFirst("content-type:".count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return ""
    }

    private nonisolated static func respond(
        connection: NWConnection,
        header: String,
        body: Data,
        stagedFiles: [URL],
        onSaved: @escaping @Sendable ([URL]) -> Void
    ) {
        let firstLine = header.split(separator: "\r\n").first.map(String.init) ?? ""
        let parts = firstLine.split(separator: " ")
        let method = parts.first.map(String.init) ?? "GET"
        let path = parts.dropFirst().first.map(String.init) ?? "/"

        if method == "POST" && path == "/upload" {
            let contentType = parseContentType(header)
            let files = AndroidDropHTML.extractMultipartFiles(body: body, contentType: contentType)
            let dropDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
                .appendingPathComponent("NotchDrop", isDirectory: true)
            try? FileManager.default.createDirectory(at: dropDir, withIntermediateDirectories: true)
            var saved: [URL] = []
            for (name, data) in files {
                let target = dropDir.appendingPathComponent(name)
                if (try? data.write(to: target, options: .atomic)) != nil {
                    saved.append(target)
                }
            }
            if !saved.isEmpty { onSaved(saved) }
            sendHTTP(connection: connection, status: "200 OK", contentType: "text/plain", body: Data("ok".utf8))
            return
        }

        if method == "GET" && path.hasPrefix("/download/"),
           let idx = Int(path.dropFirst("/download/".count)),
           stagedFiles.indices.contains(idx),
           let fileData = try? Data(contentsOf: stagedFiles[idx]) {
            let filename = stagedFiles[idx].lastPathComponent.replacingOccurrences(of: "\"", with: "")
            let head = "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Disposition: attachment; filename=\"\(filename)\"\r\nContent-Length: \(fileData.count)\r\nConnection: close\r\n\r\n"
            var packet = Data(head.utf8)
            packet.append(fileData)
            connection.send(content: packet, completion: .contentProcessed { _ in connection.cancel() })
            return
        }

        let html = AndroidDropHTML.renderPage(files: stagedFiles)
        sendHTTP(connection: connection, status: "200 OK", contentType: "text/html; charset=utf-8", body: Data(html.utf8))
    }

    private nonisolated static func sendHTTP(connection: NWConnection, status: String, contentType: String, body: Data) {
        let head = "HTTP/1.1 \(status)\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        var packet = Data(head.utf8)
        packet.append(body)
        connection.send(content: packet, completion: .contentProcessed { _ in connection.cancel() })
    }

    public static func localWiFiIPv4() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let current = ptr {
            let iface = current.pointee
            let family = iface.ifa_addr.pointee.sa_family
            if family == UInt8(AF_INET) {
                let name = String(cString: iface.ifa_name)
                if name == "en0" || name == "en1" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(iface.ifa_addr, socklen_t(iface.ifa_addr.pointee.sa_len),
                                   &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                        let ip = String(decoding: hostname.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
                        if !ip.hasPrefix("127.") { return ip }
                    }
                }
            }
            ptr = iface.ifa_next
        }
        return nil
    }

    public static func qrPNG(for text: String) -> Data? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(text.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 6, y: 6))
        let ctx = CIContext()
        let cs = CGColorSpaceCreateDeviceRGB()
        return ctx.pngRepresentation(of: scaled, format: .RGBA8, colorSpace: cs)
    }
}
