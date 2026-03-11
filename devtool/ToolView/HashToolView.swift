import SwiftUI
import AppKit
import CryptoKit
internal import UniformTypeIdentifiers

struct HashToolView: View {
    // MARK: - Options
    enum Algorithm: String, CaseIterable, Identifiable {
        case md5 = "MD5"
        case sha1 = "SHA-1"
        case sha256 = "SHA-256"
        case sha384 = "SHA-384"
        case sha512 = "SHA-512"
        var id: String { rawValue }
    }
    
    enum OutputFormat: String, CaseIterable, Identifiable {
        case hexLower = "Hex (lowercase)"
        case hexUpper = "Hex (UPPERCASE)"
        case base64   = "Base64"
        var id: String { rawValue }
    }
    
    enum TextEncoding: String, CaseIterable, Identifiable {
        case utf8 = "UTF-8"
        case ascii = "ASCII"
        case utf16 = "UTF-16"
        var id: String { rawValue }
        var nsEncoding: String.Encoding {
            switch self {
            case .utf8:  return .utf8
            case .ascii: return .ascii
            case .utf16: return .utf16LittleEndian
            }
        }
    }
    
    // Persisted preferences
    @AppStorage("hash.algorithm") private var algorithm: Algorithm = .sha256
    @AppStorage("hash.outputFormat") private var outputFormat: OutputFormat = .hexLower
    @AppStorage("hash.encoding") private var stringEncoding: TextEncoding = .utf8
    @AppStorage("hash.autoUpdate") private var autoUpdate: Bool = true
    
    // States
    @State private var input: String = ""
    @State private var output: String = ""
    @State private var errorMessage: String?
    @State private var isTargeted: Bool = false
    @State private var showInspector: Bool = true
    
    // File hashing states
    @State private var droppedFileURL: URL?
    @State private var droppedFileSize: Int64 = 0
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            editors
            Divider()
            footer
        }
        .navigationTitle("Hash (MD5 / SHA‑1 / SHA‑256 / SHA‑384 / SHA‑512)")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    computeHash()
                } label: {
                    Label("Hash", systemImage: "shield.checkerboard")
                }
                .keyboardShortcut(.return)
                
                Button {
                    copyOutput()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .disabled(output.isEmpty)
                
                Button {
                    pasteToInput()
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                
                Button(role: .destructive) {
                    clearAll()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .keyboardShortcut("k", modifiers: [.command])

                Spacer()

                Button { withAnimation { showInspector.toggle() } } label: {
                    Label("Toggle Sidebar", systemImage: "sidebar.trailing")
                }
                .help("Toggle Results Sidebar")
            }
        }
        .padding(.bottom, 4)
        .onChange(of: input) { _, _ in
            if autoUpdate && droppedFileURL == nil { computeHash() }
        }
        .onChange(of: algorithm) { _, _ in if autoUpdate { computeHash() } }
        .onChange(of: outputFormat) { _, _ in if autoUpdate { computeHash() } }
        .onChange(of: stringEncoding) { _, _ in if autoUpdate && droppedFileURL == nil { computeHash() } }
        .inspector(isPresented: $showInspector) {
            inspectorContent
                .inspectorColumnWidth(min: 300, ideal: 400, max: 600)
        }
    }
    
    // MARK: - Header
    private var header: some View {
        // Đặt minimum là 200 để vừa vặn với chiều rộng của các Picker
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], alignment: .leading, spacing: 16) {
            Group {
                Picker("Thuật toán", selection: $algorithm) {
                    ForEach(Algorithm.allCases) { alg in
                        Text(alg.rawValue).tag(alg)
                    }
                }
                .frame(maxWidth: 200)
                Picker("Output", selection: $outputFormat) {
                    ForEach(OutputFormat.allCases) { fmt in
                        Text(fmt.rawValue).tag(fmt)
                    }
                }
                .frame(maxWidth: 200)
                Picker("Encoding", selection: $stringEncoding) {
                    ForEach(TextEncoding.allCases) { enc in
                        Text(enc.rawValue).tag(enc)
                    }
                }
                .frame(maxWidth: 140)
                .disabled(droppedFileURL != nil)
            }
        }
        .padding(12)
    }

    // MARK: - Editors
    private var editors: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Left: Input
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Input").font(.headline)
                    if let url = droppedFileURL {
                        Spacer()
                        Label(url.lastPathComponent, systemImage: "doc")
                            .lineLimit(1).truncationMode(.middle)
                        Text("(\(humanFileSize(bytes: droppedFileSize)))")
                            .foregroundColor(.secondary)
                        Button { removeDroppedFile() } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                        }.buttonStyle(.borderless).help("Bỏ chọn file")
                    } else {
                        Spacer()
                        Button { input = "" } label: {
                            Image(systemName: "xmark.circle").foregroundColor(.secondary)
                        }.buttonStyle(.borderless).help("Clear input")
                    }
                }
                
                TextEditor(text: Binding(
                    get: { input },
                    set: { if droppedFileURL == nil { input = $0 } }
                ))
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(isTargeted ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1))
                .disabled(droppedFileURL != nil)
                .onDrop(of: [.fileURL, .utf8PlainText], isTargeted: $isTargeted) { providers in
                    handleDrop(providers: providers)
                }
                
                HStack(spacing: 8) {
                    Button("Hash", action: computeHash)
                        .buttonStyle(.borderedProminent)
                    Button("Paste", action: pasteToInput)
                        .disabled(droppedFileURL != nil)
                    Spacer()
                    Button("Clear", role: .destructive, action: clearAll)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var inspectorContent: some View {
        // Right: Output
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Output").font(.headline)
                Spacer()
                Button { copyOutput() } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .disabled(output.isEmpty)
            }
            
            TextEditor(text: .constant(output))
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                .disabled(true)
            
            if let error = errorMessage, !error.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.yellow)
                    Text(error).foregroundColor(.secondary)
                }
            } else { Text(" ").hidden() }
            
            HStack {
                Button("Copy Output", action: copyOutput)
                    .buttonStyle(.borderedProminent)
                    .disabled(output.isEmpty)
                Spacer()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
    
    // MARK: - Footer
    private var footer: some View {
        HStack(spacing: 12) {
            Text(footerHelp)
                .foregroundColor(.secondary)
                .font(.callout)
            Spacer()
        }
        .padding(8)
    }
    
    private var footerHelp: String {
        switch algorithm {
        case .md5:
            return "MD5 KHÔNG an toàn cho mục đích mật mã. Chỉ dùng để kiểm tra toàn vẹn."
        case .sha1:
            return "SHA‑1 KHÔNG an toàn cho mục đích mật mã. Ưu tiên SHA‑256/384/512."
        case .sha256:
            return "SHA‑256 phù hợp để kiểm tra toàn vẹn và các mục đích an toàn hơn."
        case .sha384:
            return "SHA‑384 cung cấp độ bảo mật cao hơn SHA‑256."
        case .sha512:
            return "SHA‑512 có độ dài băm lớn, phù hợp dữ liệu lớn & yêu cầu bảo mật cao."
        }
    }
    
    // MARK: - Actions
    private func computeHash() {
        errorMessage = nil
        output = ""
        
        // 1) Input data
        var data: Data
        if let fileURL = droppedFileURL {
            do {
                data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
            } catch {
                errorMessage = "Không đọc được file: \(error.localizedDescription)"
                return
            }
        } else {
            guard let d = input.data(using: stringEncoding.nsEncoding) else {
                errorMessage = "Không thể chuyển input sang dữ liệu với encoding \(stringEncoding.rawValue)."
                return
            }
            data = d
        }
        
        // 2) Digest
        let digestBytes: [UInt8]
        switch algorithm {
        case .md5:    digestBytes = Array(Insecure.MD5.hash(data: data))
        case .sha1:   digestBytes = Array(Insecure.SHA1.hash(data: data))
        case .sha256: digestBytes = Array(SHA256.hash(data: data))
        case .sha384: digestBytes = Array(SHA384.hash(data: data))
        case .sha512: digestBytes = Array(SHA512.hash(data: data))
        }
        
        // 3) Format
        switch outputFormat {
        case .hexLower:
            output = digestBytes.map { String(format: "%02x", $0) }.joined()
        case .hexUpper:
            output = digestBytes.map { String(format: "%02X", $0) }.joined()
        case .base64:
            output = Data(digestBytes).base64EncodedString()
        }
    }
    
    private func copyOutput() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(output, forType: .string)
    }
    
    private func pasteToInput() {
        guard droppedFileURL == nil else { return }
        let pb = NSPasteboard.general
        if let str = pb.string(forType: .string) { input = str }
    }
    
    private func clearAll() {
        input = ""
        output = ""
        errorMessage = nil
        removeDroppedFile()
    }
    
    private func removeDroppedFile() {
        droppedFileURL = nil
        droppedFileSize = 0
    }
    
    // MARK: - Drop handling
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                _ = provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (urlData, _) in
                    guard
                        let urlData,
                        let url = URL(dataRepresentation: urlData as! Data, relativeTo: nil)
                    else { return }
                    do {
                        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
                        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
                        DispatchQueue.main.async {
                            self.droppedFileURL = url
                            self.droppedFileSize = size
                            if self.autoUpdate { self.computeHash() }
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.errorMessage = "Không đọc được thuộc tính file."
                        }
                    }
                }
                return true
            }
            if provider.hasItemConformingToTypeIdentifier("public.utf8-plain-text") {
                _ = provider.loadObject(ofClass: NSString.self) { item, _ in
                    if let nsString = item as? NSString {
                        let text = nsString as String
                        DispatchQueue.main.async {
                            self.removeDroppedFile()
                            self.input = text
                            if self.autoUpdate { self.computeHash() }
                        }
                    }
                }
                return true
            }
        }
        return false
    }
    
    // MARK: - Utils
    private func humanFileSize(bytes: Int64) -> String {
        let units = ["B","KB","MB","GB","TB"]
        var value = Double(bytes)
        var i = 0
        while value >= 1024 && i < units.count - 1 {
            value /= 1024
            i += 1
        }
        return String(format: "%.2f %@", value, units[i])
    }
}

