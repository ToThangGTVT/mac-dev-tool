import SwiftUI
import AppKit
import Security
internal import UniformTypeIdentifiers

@Observable
class RSAViewModel {
    var operation: RSAOperation { didSet { save("rsa.operation", operation.rawValue) } }
    var msgEncoding: TextEncoding { didSet { save("rsa.msgEncoding", msgEncoding.rawValue) } }
    var binFormat: RSABinaryFormat { didSet { save("rsa.binFormat", binFormat.rawValue) } }
    var encAlg: RSAEncryptAlg { didSet { save("rsa.encAlg", encAlg.rawValue) } }
    var sigAlg: RSASignAlg { didSet { save("rsa.sigAlg", sigAlg.rawValue) } }
    
    var keySize: RSAKeySize { didSet { save("rsa.keySize", keySize.rawValue) } }
    var autofillKeysToInputs: Bool { didSet { save("rsa.autofillKeys", autofillKeysToInputs) } }
    
    var publicKeyPEM: String = ""
    var privateKeyPEM: String = ""
    var messageText: String = ""
    var binaryInput: String = ""
    var outputText: String = ""
    var errorMessage: String?
    
    var generatedPrivatePEM: String = ""
    var generatedPublicPEM: String = ""
    var isGenerating = false
    var showPreview = false
    
    init() {
        self.operation = RSAOperation(rawValue: Self.load("rsa.operation") ?? "") ?? .encrypt
        self.msgEncoding = TextEncoding(rawValue: Self.load("rsa.msgEncoding") ?? "") ?? .utf8
        self.binFormat = RSABinaryFormat(rawValue: Self.load("rsa.binFormat") ?? "") ?? .base64
        self.encAlg = RSAEncryptAlg(rawValue: Self.load("rsa.encAlg") ?? "") ?? .oaepSHA256
        self.sigAlg = RSASignAlg(rawValue: Self.load("rsa.sigAlg") ?? "") ?? .pssSHA256
        
        let savedKeySize = UserDefaults.standard.integer(forKey: "rsa.keySize")
        self.keySize = RSAKeySize(rawValue: savedKeySize) ?? .bits2048
        
        if UserDefaults.standard.object(forKey: "rsa.autofillKeys") == nil {
            self.autofillKeysToInputs = true
        } else {
            self.autofillKeysToInputs = UserDefaults.standard.bool(forKey: "rsa.autofillKeys")
        }
    }
    
    private func save(_ key: String, _ value: Any) { UserDefaults.standard.set(value, forKey: key) }
    private static func load(_ key: String) -> String? { UserDefaults.standard.string(forKey: key) }
    
    func runAction() {
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
            guard let plain = messageText.data(using: msgEncoding.nsEncoding) else {
                errorMessage = "Không chuyển message sang dữ liệu với \(msgEncoding.rawValue)."
                return
            }
            var err: Unmanaged<CFError>?
            if let cipher = SecKeyCreateEncryptedData(pub, encAlg.secKeyAlg, plain as CFData, &err) as Data? {
                outputText = encodeBinary(cipher)
            } else {
                errorMessage = (err?.takeRetainedValue() as Error?)?.localizedDescription ?? "Encrypt thất bại."
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
                if let s = String(data: plain, encoding: msgEncoding.nsEncoding) {
                    outputText = s
                } else if let utf8 = String(data: plain, encoding: .utf8) {
                    outputText = utf8
                    errorMessage = "Không decode theo \(msgEncoding.rawValue). Đã fallback UTF-8."
                } else {
                    outputText = ""
                    errorMessage = "Decrypt OK nhưng không chuyển được dữ liệu thành chuỗi."
                }
            } else {
                errorMessage = (err?.takeRetainedValue() as Error?)?.localizedDescription ?? "Decrypt thất bại."
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
            guard let msg = messageText.data(using: msgEncoding.nsEncoding) else {
                errorMessage = "Không chuyển message sang dữ liệu với \(msgEncoding.rawValue)."
                return
            }
            var err: Unmanaged<CFError>?
            if let sig = SecKeyCreateSignature(priv, sigAlg.secKeyAlg, msg as CFData, &err) as Data? {
                outputText = encodeBinary(sig)
            } else {
                errorMessage = (err?.takeRetainedValue() as Error?)?.localizedDescription ?? "Ký thất bại."
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
            guard let msg = messageText.data(using: msgEncoding.nsEncoding) else {
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
    
    func clearAll() {
        messageText = ""
        binaryInput = ""
        outputText = ""
        errorMessage = nil
    }
    
    private func encodeBinary(_ data: Data) -> String {
        switch binFormat {
        case .base64: return data.base64EncodedString()
        case .hex:    return data.map { String(format: "%02x", $0) }.joined()
        }
    }
    
    private func decodeBinary(_ s: String) -> Data? {
        switch binFormat {
        case .base64: return Data(base64Encoded: s, options: .ignoreUnknownCharacters)
        case .hex:    return Data(hexString: s)
        }
    }
    
    private func loadPublicKey(from pem: String) -> SecKey? {
        guard var der = derDataFromPEM(pem, isPublic: true) else { return nil }
        if !Self.isSPKIPublicKeyDER(der) {
            if let spki = Self.makeSPKIPublicKey(fromRSAPKCS1: der) { der = spki }
        }
        let attrs: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPublic
        ]
        var error: Unmanaged<CFError>?
        return SecKeyCreateWithData(der as CFData, attrs as CFDictionary, &error)
    }
    
    private func loadPrivateKey(from pem: String) -> SecKey? {
        guard let der = derDataFromPEM(pem, isPublic: false) else { return nil }
        let attrs: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPrivate
        ]
        var error: Unmanaged<CFError>?
        return SecKeyCreateWithData(der as CFData, attrs as CFDictionary, &error)
    }
    
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
                    .components(separatedBy: .whitespacesAndNewlines).joined()
                if let der = Data(base64Encoded: body) { return der }
            }
        }
        return nil
    }
    
    @MainActor
    func generateRSAKeyPairAsync() async {
        errorMessage = nil
        if autofillKeysToInputs {
            generatedPrivatePEM = ""
            generatedPublicPEM  = ""
            showPreview = false
        }
        isGenerating = true
        defer { isGenerating = false }
        
        let size = keySize.rawValue
        let result = await Task.detached(priority: .userInitiated) { () -> Result<(String, String), Error> in
            do {
                let (priv, pub) = try Self.generateRSAKeyPairCore(keySizeInBits: size)
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
    
    private nonisolated static func generateRSAKeyPairCore(keySizeInBits: Int) throws -> (privatePEM: String, publicPEM: String) {
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits: keySizeInBits
        ]
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw (error?.takeRetainedValue() as Error?) ?? NSError(domain: "RSATool", code: -1, userInfo: [NSLocalizedDescriptionKey: "Generate RSA private key thất bại."])
        }
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw NSError(domain: "RSATool", code: -2, userInfo: [NSLocalizedDescriptionKey: "Không lấy được public key từ private key."])
        }
        guard let privDER = SecKeyCopyExternalRepresentation(privateKey, nil) as Data? else {
            throw NSError(domain: "RSATool", code: -3, userInfo: [NSLocalizedDescriptionKey: "Không export được private key (DER)."])
        }
        guard let pubRawDER = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            throw NSError(domain: "RSATool", code: -4, userInfo: [NSLocalizedDescriptionKey: "Không export được public key (DER)."])
        }

        let privPEM = pemWrap(der: privDER, header: "-----BEGIN RSA PRIVATE KEY-----", footer: "-----END RSA PRIVATE KEY-----")

        let pubDER: Data
        if isSPKIPublicKeyDER(pubRawDER) {
            pubDER = pubRawDER
        } else {
            pubDER = makeSPKIPublicKey(fromRSAPKCS1: pubRawDER) ?? pubRawDER
        }
        let pubPEM = Self.pemWrap(der: pubDER, header: "-----BEGIN PUBLIC KEY-----", footer: "-----END PUBLIC KEY-----")

        return (privPEM, pubPEM)
    }

    private static func pemWrap(der: Data, header: String, footer: String) -> String {
        let b64 = der.base64EncodedString()
        var out = [header]
        var i = b64.startIndex
        while i < b64.endIndex {
            let next = b64.index(i, offsetBy: 64, limitedBy: b64.endIndex) ?? b64.endIndex
            out.append(String(b64[i..<next]))
            i = next
        }
        out.append(footer)
        return out.joined(separator: "\n")
    }

    private static func isSPKIPublicKeyDER(_ der: Data) -> Bool {
        let oidBytes: [UInt8] = [0x06,0x09,0x2A,0x86,0x48,0x86,0xF7,0x0D,0x01,0x01,0x01]
        if let range = der.firstRange(of: Data(oidBytes)) {
            if let idx = der.firstIndex(of: 0x03), idx > range.lowerBound { return true }
        }
        return false
    }

    private static func makeSPKIPublicKey(fromRSAPKCS1 pkcs1: Data) -> Data? {
        let oidRSA: [UInt8] = [0x06,0x09,0x2A,0x86,0x48,0x86,0xF7,0x0D,0x01,0x01,0x01]
        let nullBytes: [UInt8] = [0x05,0x00]
        let algSeq = Self.derSequence(Data(oidRSA) + Data(nullBytes))
        let bitString = Self.derBitString(pkcs1)
        return Self.derSequence(algSeq + bitString)
    }

    private static func derSequence(_ content: Data) -> Data {
        var out = Data([0x30])
        out.append(Self.derLength(content.count))
        out.append(content)
        return out
    }
    private static func derBitString(_ content: Data) -> Data {
        var out = Data([0x03])
        let wrapped = Data([0x00]) + content
        out.append(Self.derLength(wrapped.count))
        out.append(wrapped)
        return out
    }
    private static func derLength(_ len: Int) -> Data {
        if len < 0x80 { return Data([UInt8(len)]) }
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

    func savePEM(_ pem: String, suggestedName: String) {
        let panel = NSSavePanel()
        if #available(macOS 11.0, *) {
            if let pemType = UTType(filenameExtension: "pem") {
                panel.allowedContentTypes = [pemType]
            } else {
                panel.allowedContentTypes = [.data]
            }
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
}
