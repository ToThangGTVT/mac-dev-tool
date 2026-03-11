import SwiftUI
import AppKit
import Security
internal import UniformTypeIdentifiers

struct RSAToolView: View {
    // MARK: - RSA Ops Enums
    enum Operation: String, CaseIterable, Identifiable {
        case encrypt = "Encrypt"
        case decrypt = "Decrypt"
        case sign    = "Sign"
        case verify  = "Verify"
        var id: String { rawValue }
    }
    enum MessageEncoding: String, CaseIterable, Identifiable {
        case utf8 = "UTF-8"
        case ascii = "ASCII"
        case utf16 = "UTF-16"
        var id: String { rawValue }
        var ns: String.Encoding {
            switch self {
            case .utf8:  return .utf8
            case .ascii: return .ascii
            case .utf16: return .utf16LittleEndian
            }
        }
    }
    enum BinaryFormat: String, CaseIterable, Identifiable {
        case base64 = "Base64"
        case hex    = "Hex"
        var id: String { rawValue }
    }
    enum RSAEncryptAlg: String, CaseIterable, Identifiable {
        case pkcs1         = "RSAES-PKCS1-v1_5"
        case oaepSHA1      = "RSAES-OAEP (SHA-1)"
        case oaepSHA256    = "RSAES-OAEP (SHA-256)"
        var id: String { rawValue }
        var secKeyAlg: SecKeyAlgorithm {
            switch self {
            case .pkcs1:      return .rsaEncryptionPKCS1
            case .oaepSHA1:   return .rsaEncryptionOAEPSHA1
            case .oaepSHA256: return .rsaEncryptionOAEPSHA256
            }
        }
    }
    enum RSASignAlg: String, CaseIterable, Identifiable {
        case pssSHA256     = "RSASSA-PSS (SHA-256)"
        case pssSHA1       = "RSASSA-PSS (SHA-1)"
        case pkcs1SHA256   = "PKCS#1 v1.5 (SHA-256)"
        case pkcs1SHA1     = "PKCS#1 v1.5 (SHA-1)"
        var id: String { rawValue }
        var secKeyAlg: SecKeyAlgorithm {
            switch self {
            case .pssSHA256:   return .rsaSignatureMessagePSSSHA256
            case .pssSHA1:     return .rsaSignatureMessagePSSSHA1
            case .pkcs1SHA256: return .rsaSignatureMessagePKCS1v15SHA256
            case .pkcs1SHA1:   return .rsaSignatureMessagePKCS1v15SHA1
            }
        }
    }

    // MARK: - KeyGen
    private enum KeySize: Int, CaseIterable, Identifiable {
        case bits2048 = 2048
        case bits3072 = 3072
        case bits4096 = 4096
        var id: Int { rawValue }
        var label: String { "\(rawValue) bits" }
    }

    // MARK: - Persisted preferences
    @AppStorage("rsa.operation") private var operation: Operation = .encrypt
    @AppStorage("rsa.msgEncoding") private var msgEncoding: MessageEncoding = .utf8
    @AppStorage("rsa.binFormat") private var binFormat: BinaryFormat = .base64
    @AppStorage("rsa.encAlg") private var encAlg: RSAEncryptAlg = .oaepSHA256
    @AppStorage("rsa.sigAlg") private var sigAlg: RSASignAlg = .pssSHA256

    // KeyGen prefs
    @AppStorage("rsa.keySize") private var keySize: KeySize = .bits2048
    @AppStorage("rsa.autofillKeys") private var autofillKeysToInputs: Bool = true

    // MARK: - Inputs & state
    @State private var publicKeyPEM: String = ""
    @State private var privateKeyPEM: String = ""
    @State private var messageText: String = ""
    @State private var binaryInput: String = ""   // ciphertext (Decrypt) / signature (Verify)
    @State private var outputText: String = ""
    @State private var errorMessage: String?
    @State private var showInspector: Bool = true

    // Generated (preview)
    @State private var generatedPrivatePEM: String = ""
    @State private var generatedPublicPEM: String = ""

    // Spinner & preview control
    @State private var isGenerating = false
    @State private var showPreview = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .navigationTitle("RSA (Encrypt / Decrypt / Sign / Verify) + KeyGen")
        .toolbar {
            ToolbarItemGroup {
                Button(action: runAction) {
                    Label(actionTitle, systemImage: "play.circle")
                }
                .keyboardShortcut(.return)

                Button { copyOutput() } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .disabled(outputText.isEmpty)

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
        .inspector(isPresented: $showInspector) {
            inspectorContent
                .inspectorColumnWidth(min: 300, ideal: 400, max: 600)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Header
    private var header: some View {
        // Đặt minimum khoảng 220 để cân bằng giữa các Picker có kích thước từ 140 đến 260
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220))], alignment: .leading, spacing: 16) {
            
            Picker("Operation", selection: $operation) {
                ForEach(Operation.allCases) { Text($0.rawValue).tag($0) }
            }
            .frame(minWidth: 160)

            if operation == .encrypt || operation == .decrypt {
                Picker("Algorithm", selection: $encAlg) {
                    ForEach(RSAEncryptAlg.allCases) { Text($0.rawValue).tag($0) }
                }
                .frame(minWidth: 240)
            } else {
                Picker("Algorithm", selection: $sigAlg) {
                    ForEach(RSASignAlg.allCases) { Text($0.rawValue).tag($0) }
                }
                .frame(minWidth: 260)
            }

            if operation == .encrypt || operation == .sign || operation == .verify {
                Picker("Message Encoding", selection: $msgEncoding) {
                    ForEach(MessageEncoding.allCases) { Text($0.rawValue).tag($0) }
                }
                .frame(minWidth: 160)
            }

            Picker("Binary Format", selection: $binFormat) {
                ForEach(BinaryFormat.allCases) { Text($0.rawValue).tag($0) }
            }
            .frame(minWidth: 200)
            .help("Định dạng vào/ra cho ciphertext hoặc signature")
            
            Spacer()
            
        }
        .padding(12)
    }
    
    // MARK: - Content (có KeyGen + vùng nhập khoá, message, binary)
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                keyGenerator
                Group {
                    HStack {
                        Text("Public Key (PEM)").font(.headline)
                        Spacer()
                        if operation == .encrypt || operation == .verify {
                            Text("Cần PUBLIC KEY").foregroundColor(.secondary)
                        }
                    }
                    TextEditor(text: $publicKeyPEM)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 90)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1))

                    HStack {
                        Text("Private Key (PEM)").font(.headline)
                        Spacer()
                        if operation == .decrypt || operation == .sign {
                            Text("Cần PRIVATE KEY").foregroundColor(.secondary)
                        }
                    }
                    TextEditor(text: $privateKeyPEM)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 90)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                }
                Group {
                    if operation == .encrypt || operation == .sign || operation == .verify {
                        HStack {
                            Text(operation == .verify ? "Message (để verify)" : "Message")
                                .font(.headline)
                            Spacer()
                            Button { messageText = "" } label: {
                                Image(systemName: "xmark.circle").foregroundColor(.secondary)
                            }.buttonStyle(.borderless)
                        }
                        TextEditor(text: $messageText)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 110)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                    }

                    if operation == .decrypt || operation == .verify {
                        HStack {
                            Text(operation == .decrypt ? "Ciphertext (\(binFormat.rawValue))" : "Signature (\(binFormat.rawValue))")
                                .font(.headline)
                            Spacer()
                            Button { binaryInput = "" } label: {
                                Image(systemName: "xmark.circle").foregroundColor(.secondary)
                            }.buttonStyle(.borderless)
                        }
                        TextEditor(text: $binaryInput)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 90)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                    }
                }

                HStack(spacing: 8) {
                    Button(actionTitle, action: runAction)
                        .buttonStyle(.borderedProminent)
                    Spacer()
                    Button("Clear", role: .destructive, action: clearAll)
                }
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var inspectorContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Output").font(.headline)
                Spacer()
                Button { copyOutput() } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .disabled(outputText.isEmpty)
            }

            TextEditor(text: .constant(outputText))
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 220)
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                .disabled(true)

            if let e = errorMessage, !e.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.yellow)
                    Text(e).foregroundColor(.secondary)
                }
            } else { Text(" ").hidden() }

            HStack {
                Button("Copy Output", action: copyOutput)
                    .buttonStyle(.borderedProminent)
                    .disabled(outputText.isEmpty)
                Spacer()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Key Generator UI (có spinner + tránh trùng view)
    private var keyGenerator: some View {
        GroupBox("Key Generator (RSA)") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Picker("Key size", selection: $keySize) {
                        ForEach(KeySize.allCases) { size in
                            Text(size.label).tag(size)
                        }
                    }
                    .frame(width: 180)
                    .disabled(isGenerating)

                    Spacer()

                    Button {
                        Task { await generateRSAKeyPairAsync() }
                    } label: {
                        HStack(spacing: 6) {
                            if isGenerating {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.9)
                            } else {
                                Image(systemName: "key.horizontal")
                            }
                            Text(isGenerating ? "Generating…" : "Generate")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isGenerating)
                }

                // Chỉ hiển thị Preview khi KHÔNG autofill để tránh "trùng"
                if !autofillKeysToInputs {
                    Toggle("Hiển thị bản xem trước PEM", isOn: $showPreview)
                        .disabled(isGenerating)

                    if showPreview, (!generatedPrivatePEM.isEmpty || !generatedPublicPEM.isEmpty) {
                        Divider().padding(.vertical, 2)

                        Text("Private Key (PEM)").font(.headline)
                        TextEditor(text: .constant(generatedPrivatePEM))
                            .font(.system(.caption, design: .monospaced))
                            .frame(minHeight: 90)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                            .disabled(true)

                        HStack(spacing: 8) {
                            Button { copyToPasteboard(generatedPrivatePEM) } label: {
                                Label("Copy Private", systemImage: "doc.on.doc")
                            }
                            Button { savePEM(generatedPrivatePEM, suggestedName: "rsa_private_\(keySize.rawValue).pem") } label: {
                                Label("Save Private…", systemImage: "square.and.arrow.down")
                            }
                        }

                        Text("Public Key (PEM)").font(.headline).padding(.top, 6)
                        TextEditor(text: .constant(generatedPublicPEM))
                            .font(.system(.caption, design: .monospaced))
                            .frame(minHeight: 90)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                            .disabled(true)

                        HStack(spacing: 8) {
                            Button { copyToPasteboard(generatedPublicPEM) } label: {
                                Label("Copy Public", systemImage: "doc.on.doc")
                            }
                            Button { savePEM(generatedPublicPEM, suggestedName: "rsa_public_\(keySize.rawValue).pem") } label: {
                                Label("Save Public…", systemImage: "square.and.arrow.down")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Footer
    private var footer: some View {
        HStack {
            Text(footerHelp)
                .foregroundColor(.secondary)
                .font(.callout)
            Spacer()
        }
        .padding(8)
    }
    private var footerHelp: String {
        switch operation {
        case .encrypt:
            return "Encrypt: dùng PUBLIC KEY. OAEP an toàn hơn PKCS#1 v1.5. Plaintext phải nhỏ hơn modulus."
        case .decrypt:
            return "Decrypt: dùng PRIVATE KEY. Chọn đúng thuật toán (PKCS#1 hoặc OAEP SHA‑1/SHA‑256)."
        case .sign:
            return "Sign: dùng PRIVATE KEY. PSS an toàn hơn PKCS#1 v1.5. Output là chữ ký (Base64/Hex)."
        case .verify:
            return "Verify: dùng PUBLIC KEY, nhập message + signature (Base64/Hex)."
        }
    }
    private var actionTitle: String {
        switch operation {
        case .encrypt: return "Encrypt"
        case .decrypt: return "Decrypt"
        case .sign:    return "Sign"
        case .verify:  return "Verify"
        }
    }

    // MARK: - Actions (Encrypt/Decrypt/Sign/Verify)
    private func runAction() {
        errorMessage = nil
        outputText = ""

        switch operation {
        case .encrypt:
            guard let pub = loadPublicKey(from: publicKeyPEM) else {
                errorMessage = "Không tải được PUBLIC KEY (PEM)."
                return
            }
            guard SecKeyIsAlgorithmSupported(pub, .encrypt, encAlg.secKeyAlg) else {
                errorMessage = "Thuật toán không được key hỗ trợ."
                return
            }
            guard let plain = messageText.data(using: msgEncoding.ns) else {
                errorMessage = "Không chuyển message sang dữ liệu với \(msgEncoding.rawValue)."
                return
            }
            var err: Unmanaged<CFError>?
            if let cipher = SecKeyCreateEncryptedData(pub, encAlg.secKeyAlg, plain as CFData, &err) as Data? {
                outputText = encodeBinary(cipher)
            } else {
                errorMessage = (err?.takeRetainedValue() as Error?)?.localizedDescription
                    ?? "Encrypt thất bại."
            }

        case .decrypt:
            guard let priv = loadPrivateKey(from: privateKeyPEM) else {
                errorMessage = "Không tải được PRIVATE KEY (PEM)."
                return
            }
            guard SecKeyIsAlgorithmSupported(priv, .decrypt, encAlg.secKeyAlg) else {
                errorMessage = "Thuật toán không được key hỗ trợ."
                return
            }
            guard let cipher = decodeBinary(binaryInput) else {
                errorMessage = "Không đọc được ciphertext theo định dạng \(binFormat.rawValue)."
                return
            }
            var err: Unmanaged<CFError>?
            if let plain = SecKeyCreateDecryptedData(priv, encAlg.secKeyAlg, cipher as CFData, &err) as Data? {
                if let s = String(data: plain, encoding: msgEncoding.ns) {
                    outputText = s
                } else if let utf8 = String(data: plain, encoding: .utf8) {
                    outputText = utf8
                    errorMessage = "Không decode theo \(msgEncoding.rawValue). Đã fallback UTF‑8."
                } else {
                    outputText = ""
                    errorMessage = "Decrypt OK nhưng không chuyển được dữ liệu thành chuỗi."
                }
            } else {
                errorMessage = (err?.takeRetainedValue() as Error?)?.localizedDescription
                    ?? "Decrypt thất bại."
            }

        case .sign:
            guard let priv = loadPrivateKey(from: privateKeyPEM) else {
                errorMessage = "Không tải được PRIVATE KEY (PEM)."
                return
            }
            guard SecKeyIsAlgorithmSupported(priv, .sign, sigAlg.secKeyAlg) else {
                errorMessage = "Thuật toán không được key hỗ trợ."
                return
            }
            guard let msg = messageText.data(using: msgEncoding.ns) else {
                errorMessage = "Không chuyển message sang dữ liệu với \(msgEncoding.rawValue)."
                return
            }
            var err: Unmanaged<CFError>?
            if let sig = SecKeyCreateSignature(priv, sigAlg.secKeyAlg, msg as CFData, &err) as Data? {
                outputText = encodeBinary(sig)
            } else {
                errorMessage = (err?.takeRetainedValue() as Error?)?.localizedDescription
                    ?? "Ký thất bại."
            }

        case .verify:
            guard let pub = loadPublicKey(from: publicKeyPEM) else {
                errorMessage = "Không tải được PUBLIC KEY (PEM)."
                return
            }
            guard SecKeyIsAlgorithmSupported(pub, .verify, sigAlg.secKeyAlg) else {
                errorMessage = "Thuật toán không được key hỗ trợ."
                return
            }
            guard let msg = messageText.data(using: msgEncoding.ns) else {
                errorMessage = "Không chuyển message sang dữ liệu với \(msgEncoding.rawValue)."
                return
            }
            guard let sig = decodeBinary(binaryInput) else {
                errorMessage = "Không đọc được signature theo định dạng \(binFormat.rawValue)."
                return
            }
            var err: Unmanaged<CFError>?
            let ok = SecKeyVerifySignature(pub, sigAlg.secKeyAlg, msg as CFData, sig as CFData, &err)
            outputText = ok ? "✅ Signature hợp lệ" : "❌ Signature KHÔNG hợp lệ"
            if !ok {
                errorMessage = (err?.takeRetainedValue() as Error?)?.localizedDescription
            }
        }
    }

    private func copyOutput() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(outputText, forType: .string)
    }
    private func clearAll() {
        messageText = ""
        binaryInput = ""
        outputText = ""
        errorMessage = nil
        // Giữ lựa chọn thuật toán và PEM để test tiếp
    }

    // MARK: - Binary helpers
    private func encodeBinary(_ data: Data) -> String {
        switch binFormat {
        case .base64: return data.base64EncodedString()
        case .hex:    return data.map { String(format: "%02x", $0) }.joined()
        }
    }
    private func decodeBinary(_ s: String) -> Data? {
        switch binFormat {
        case .base64:
            return Data(base64Encoded: s, options: .ignoreUnknownCharacters)
        case .hex:
            return Data(hexString: s)
        }
    }

    // MARK: - Key loading (PEM)
    private func loadPublicKey(from pem: String) -> SecKey? {
        guard var der = derDataFromPEM(pem, isPublic: true) else { return nil }
        // Nếu là PKCS#1 (RSA PUBLIC KEY), bọc sang SPKI trước khi tạo SecKey
        if !isSPKIPublicKeyDER(der) {
            if let spki = makeSPKIPublicKey(fromRSAPKCS1: der) {
                der = spki
            }
        }
        let attrs: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPublic
        ]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(der as CFData, attrs as CFDictionary, &error) else {
            return nil
        }
        return key
    }
    private func loadPrivateKey(from pem: String) -> SecKey? {
        guard let der = derDataFromPEM(pem, isPublic: false) else { return nil }
        let attrs: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPrivate
        ]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(der as CFData, attrs as CFDictionary, &error) else {
            return nil
        }
        return key
    }

    /// Trích DER từ PEM. Hỗ trợ:
    /// - Public: "BEGIN PUBLIC KEY" (SPKI) hoặc "BEGIN RSA PUBLIC KEY" (PKCS#1)
    /// - Private: "BEGIN PRIVATE KEY" (PKCS#8) hoặc "BEGIN RSA PRIVATE KEY" (PKCS#1)
    /// *PEM phải không mã hoá.*
    private func derDataFromPEM(_ pem: String, isPublic: Bool) -> Data? {
        let cleaned = pem.replacingOccurrences(of: "\r", with: "")
        let candidates: [(begin: String, end: String)] = isPublic
        ? [("-----BEGIN PUBLIC KEY-----", "-----END PUBLIC KEY-----"),
           ("-----BEGIN RSA PUBLIC KEY-----", "-----END RSA PUBLIC KEY-----")]
        : [("-----BEGIN PRIVATE KEY-----", "-----END PRIVATE KEY-----"),
           ("-----BEGIN RSA PRIVATE KEY-----", "-----END RSA PRIVATE KEY-----")]
        for c in candidates {
            if let r1 = cleaned.range(of: c.begin),
               let r2 = cleaned.range(of: c.end),
               r1.upperBound <= r2.lowerBound {
                let body = cleaned[r1.upperBound..<r2.lowerBound]
                    .components(separatedBy: .whitespacesAndNewlines)
                    .joined()
                if let der = Data(base64Encoded: body) { return der }
            }
        }
        return nil
    }

    // MARK: - KeyGen (Async để spinner quay)
    @MainActor
    private func generateRSAKeyPairAsync() async {
        // Reset lỗi/preview theo mode
        errorMessage = nil
        if autofillKeysToInputs {
            generatedPrivatePEM = ""
            generatedPublicPEM  = ""
            showPreview = false
        }

        isGenerating = true
        defer { isGenerating = false }

        let result = await Task.detached(priority: .userInitiated) { () -> Result<(String, String), Error> in
            do {
                let (priv, pub) = try generateRSAKeyPairCore()
                return .success((priv, pub))
            } catch {
                return .failure(error)
            }
        }.value

        switch result {
        case .success(let (privPEM, pubPEM)):
            if autofillKeysToInputs {
                privateKeyPEM = privPEM
                publicKeyPEM  = pubPEM
            } else {
                generatedPrivatePEM = privPEM
                generatedPublicPEM  = pubPEM
                if !showPreview { showPreview = true }
            }
        case .failure(let err):
            errorMessage = err.localizedDescription
        }
    }

    /// Sinh cặp khóa + export PEM (chạy background)
    private func generateRSAKeyPairCore() throws -> (privatePEM: String, publicPEM: String) {
        // 1) Tạo key
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits: keySize.rawValue
            // kSecAttrIsPermanent: false
        ]
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw (error?.takeRetainedValue() as Error?) ?? NSError(domain: "RSATool", code: -1, userInfo: [NSLocalizedDescriptionKey: "Generate RSA private key thất bại."])
        }
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw NSError(domain: "RSATool", code: -2, userInfo: [NSLocalizedDescriptionKey: "Không lấy được public key từ private key."])
        }

        // 2) Export DER
        guard let privDER = SecKeyCopyExternalRepresentation(privateKey, nil) as Data? else {
            throw NSError(domain: "RSATool", code: -3, userInfo: [NSLocalizedDescriptionKey: "Không export được private key (DER)."])
        }
        guard let pubRawDER = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            throw NSError(domain: "RSATool", code: -4, userInfo: [NSLocalizedDescriptionKey: "Không export được public key (DER)."])
        }

        // 3) Private → PKCS#1 PEM
        let privPEM = pemWrap(der: privDER,
                              header: "-----BEGIN RSA PRIVATE KEY-----",
                              footer: "-----END RSA PRIVATE KEY-----")

        // 4) Public → SPKI nếu cần → BEGIN PUBLIC KEY
        let pubDER: Data
        if isSPKIPublicKeyDER(pubRawDER) {
            pubDER = pubRawDER
        } else {
            pubDER = makeSPKIPublicKey(fromRSAPKCS1: pubRawDER) ?? pubRawDER
        }
        let pubPEM = pemWrap(der: pubDER,
                             header: "-----BEGIN PUBLIC KEY-----",
                             footer: "-----END PUBLIC KEY-----")

        return (privPEM, pubPEM)
    }

    // MARK: - PEM helpers
    private func pemWrap(der: Data, header: String, footer: String) -> String {
        let b64 = der.base64EncodedString()
        let wrapped = wrapBase64(b64, every: 64)
        return "\(header)\n\(wrapped)\n\(footer)"
    }
    private func wrapBase64(_ s: String, every n: Int) -> String {
        guard n > 0 else { return s }
        var out: [String] = []
        out.reserveCapacity((s.count / n) + 1)
        var index = s.startIndex
        while index < s.endIndex {
            let end = s.index(index, offsetBy: n, limitedBy: s.endIndex) ?? s.endIndex
            out.append(String(s[index..<end]))
            index = end
        }
        return out.joined(separator: "\n")
    }

    private func copyToPasteboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
    private func savePEM(_ pem: String, suggestedName: String) {
        let panel = NSSavePanel()
        if #available(macOS 11.0, *) {
            if let pemType = UTType(filenameExtension: "pem") {
                panel.allowedContentTypes = [pemType]
            } else {
                panel.allowedContentTypes = [.data]
            }
        } else {
            panel.allowedFileTypes = ["pem"]
        }
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try pem.data(using: .utf8)?.write(to: url)
            } catch {
                self.errorMessage = "Lưu tệp thất bại: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Public SPKI wrapper
    /// Kiểm tra DER có phải SPKI (SubjectPublicKeyInfo) cho RSA không (heuristic).
    private func isSPKIPublicKeyDER(_ der: Data) -> Bool {
        // OID rsaEncryption: 06 09 2A 86 48 86 F7 0D 01 01 01
        let oidBytes: [UInt8] = [0x06,0x09,0x2A,0x86,0x48,0x86,0xF7,0x0D,0x01,0x01,0x01]
        if let range = der.firstRange(of: Data(oidBytes)) {
            // Thường có NULL (05 00) & BIT STRING (03) theo sau
            if let idx = der.firstIndex(of: 0x03), idx > range.lowerBound { return true }
        }
        return false
    }

    /// Bọc RSAPublicKey (PKCS#1) vào SPKI (X.509 SubjectPublicKeyInfo)
    private func makeSPKIPublicKey(fromRSAPKCS1 pkcs1: Data) -> Data? {
        // AlgorithmIdentifier: SEQUENCE { OID rsaEncryption, NULL }
        let oidRSA: [UInt8] = [0x06,0x09,0x2A,0x86,0x48,0x86,0xF7,0x0D,0x01,0x01,0x01] // 1.2.840.113549.1.1.1
        let nullBytes: [UInt8] = [0x05,0x00]
        let algSeq = derSequence(Data(oidRSA) + Data(nullBytes))

        // subjectPublicKey: BIT STRING of RSAPublicKey DER (prefix 0 unused bits)
        let bitString = derBitString(pkcs1)

        // SPKI: SEQUENCE { algSeq, bitString }
        return derSequence(algSeq + bitString)
    }

    // --- Minimal DER helpers ---
    private func derSequence(_ content: Data) -> Data {
        var out = Data([0x30]) // SEQUENCE
        out.append(derLength(content.count))
        out.append(content)
        return out
    }
    private func derBitString(_ content: Data) -> Data {
        var out = Data([0x03]) // BIT STRING
        let wrapped = Data([0x00]) + content // 0 unused bits
        out.append(derLength(wrapped.count))
        out.append(wrapped)
        return out
    }
    private func derLength(_ len: Int) -> Data {
        if len < 0x80 {
            return Data([UInt8(len)])
        }
        // long form
        var bytes: [UInt8] = []
        var v = len
        while v > 0 {
            bytes.insert(UInt8(v & 0xFF), at: 0)
            v >>= 8
        }
        var out = Data([0x80 | UInt8(bytes.count)])
        out.append(contentsOf: bytes)
        return out
    }
}

// MARK: - Data hex helpers
private extension Data {
    init?(hexString: String) {
        let s = hexString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
        guard s.count % 2 == 0 else { return nil }
        var data = Data(capacity: s.count / 2)
        var index = s.startIndex
        while index < s.endIndex {
            let next = s.index(index, offsetBy: 2)
            let byteStr = s[index..<next]
            if let b = UInt8(byteStr, radix: 16) {
                data.append(b)
            } else {
                return nil
            }
            index = next
        }
        self = data
    }

    /// Tìm subdata (tiện cho heuristic SPKI)
    func firstRange(of sub: Data) -> Range<Data.Index>? {
        guard !sub.isEmpty, sub.count <= self.count else { return nil }
        return self.withUnsafeBytes { buf in
            return sub.withUnsafeBytes { subBuf in
                for i in 0...(self.count - sub.count) {
                    if memcmp(buf.baseAddress!.advanced(by: i), subBuf.baseAddress!, sub.count) == 0 {
                        return i..<i+sub.count
                    }
                }
                return nil
            }
        }
    }
}

