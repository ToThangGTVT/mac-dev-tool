import Foundation
import CryptoKit


@Observable
class Base64ViewModel {
    var algorithm: UnifiedAlgorithm = .base64 {
        didSet {
            UserDefaults.standard.set(algorithm.rawValue, forKey: "base64.algorithm")
            performMainAction()
        }
    }
    
    var mode: Base64Mode = .encode {
        didSet { 
            UserDefaults.standard.set(mode.rawValue, forKey: "base64.mode")
            performMainAction() 
        }
    }
    
    var wrap: Base64Wrap = .none {
        didSet { 
            UserDefaults.standard.set(wrap.rawValue, forKey: "base64.wrap")
            performMainAction() 
        }
    }
    
    var lineEnding: Base64LineEnding = .lf {
        didSet { 
            UserDefaults.standard.set(lineEnding.rawValue, forKey: "base64.lineEnding")
            performMainAction() 
        }
    }
    
    var stringEncoding: TextEncoding = .utf8 {
        didSet { 
            UserDefaults.standard.set(stringEncoding.rawValue, forKey: "base64.encoding")
            if droppedFileURL == nil { performMainAction() }
        }
    }
    
    var hashOutputFormat: HashOutputFormat = .hexLower {
        didSet {
            UserDefaults.standard.set(hashOutputFormat.rawValue, forKey: "base64.hashOutputFormat")
            performMainAction()
        }
    }
    
    var input: String = "" {
        didSet { 
            if input != oldValue && droppedFileURL == nil {
                if algorithm == .base64 { autoDetectModeIfNeeded() }
                performMainAction() 
            }
        }
    }
    
    var targetHash: String = "" {
        didSet {
            if algorithm.isHash && mode == .decode {
                performMainAction()
            }
        }
    }
    var output: String = ""
    var errorMessage: String?
    
    var droppedFileURL: URL? = nil {
        didSet {
            performMainAction()
        }
    }
    var droppedFileSize: Int64 = 0
    
    init() {
        self.algorithm = UnifiedAlgorithm(rawValue: UserDefaults.standard.string(forKey: "base64.algorithm") ?? "") ?? .base64
        self.mode = Base64Mode(rawValue: UserDefaults.standard.string(forKey: "base64.mode") ?? "") ?? .encode
        self.wrap = Base64Wrap(rawValue: UserDefaults.standard.string(forKey: "base64.wrap") ?? "") ?? .none
        self.lineEnding = Base64LineEnding(rawValue: UserDefaults.standard.string(forKey: "base64.lineEnding") ?? "") ?? .lf
        self.stringEncoding = TextEncoding(rawValue: UserDefaults.standard.string(forKey: "base64.encoding") ?? "") ?? .utf8
        self.hashOutputFormat = HashOutputFormat(rawValue: UserDefaults.standard.string(forKey: "base64.hashOutputFormat") ?? "") ?? .hexLower
    }
    
    func performMainAction() {
        errorMessage = nil
        output = ""
        
        let data: Data
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
        
        if algorithm == .base64 {
            handleBase64(data: data)
        } else {
            handleHash(data: data)
        }
    }
    
    private func handleBase64(data: Data) {
        switch mode {
        case .encode:
            var options: Data.Base64EncodingOptions = []
            switch wrap {
            case .w64: options.insert(.lineLength64Characters)
            case .w76: options.insert(.lineLength76Characters)
            case .none: break
            }
            switch lineEnding {
            case .lf:   options.insert(.endLineWithLineFeed)
            case .crlf: options.insert(.endLineWithCarriageReturn)
            }
            output = data.base64EncodedString(options: options)
            
        case .decode:
            if droppedFileURL != nil {
                errorMessage = "Decode Base64 cho File chưa được hỗ trợ."
                return
            }
            guard let inputData = Data(base64Encoded: input, options: .ignoreUnknownCharacters) else {
                errorMessage = "Input không phải Base64 hợp lệ."
                return
            }
            if let str = String(data: inputData, encoding: stringEncoding.nsEncoding) {
                output = str
            } else if let utf8 = String(data: inputData, encoding: .utf8) {
                output = utf8
                errorMessage = "Không decode được với \(stringEncoding.rawValue). Đã fallback UTF-8."
            } else {
                errorMessage = "Không thể chuyển dữ liệu đã decode thành chuỗi văn bản."
            }
        }
    }
    
    private func handleHash(data: Data) {
        let digestBytes: [UInt8]
        switch algorithm {
        case .md5:    digestBytes = Array(Insecure.MD5.hash(data: data))
        case .sha1:   digestBytes = Array(Insecure.SHA1.hash(data: data))
        case .sha256: digestBytes = Array(SHA256.hash(data: data))
        case .sha384: digestBytes = Array(SHA384.hash(data: data))
        case .sha512: digestBytes = Array(SHA512.hash(data: data))
        case .base64: return
        }
        
        let computedHash: String
        switch hashOutputFormat {
        case .hexLower:
            computedHash = digestBytes.map { String(format: "%02x", $0) }.joined()
        case .hexUpper:
            computedHash = digestBytes.map { String(format: "%02X", $0) }.joined()
        case .base64:
            computedHash = Data(digestBytes).base64EncodedString()
        }
        
        if mode == .encode {
            output = computedHash
        } else {
            let target = targetHash.trimmingCharacters(in: .whitespacesAndNewlines)
            if target.isEmpty {
                output = "Vui lòng nhập Hash cần đối chiếu (Target Hash)."
            } else if computedHash.lowercased() == target.lowercased() {
                output = "✅ MATCH\n\nComputed: \(computedHash)\nTarget: \(target)"
            } else {
                output = "❌ MISMATCH\n\nComputed: \(computedHash)\nTarget: \(target)"
            }
        }
    }
    
    func swapMode() {
        if algorithm != .base64 { return }
        mode = (mode == .encode) ? .decode : .encode
        output = ""
        errorMessage = nil
    }
    
    func clearAll() {
        input = ""
        output = ""
        errorMessage = nil
        removeDroppedFile()
    }
    
    func removeDroppedFile() {
        droppedFileURL = nil
        droppedFileSize = 0
    }
    
    func humanFileSize(bytes: Int64) -> String {
        let units = ["B","KB","MB","GB","TB"]
        var value = Double(bytes)
        var i = 0
        while value >= 1024 && i < units.count - 1 {
            value /= 1024
            i += 1
        }
        return String(format: "%.2f %@", value, units[i])
    }
    
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (urlData, _) in
                    guard let urlData = urlData as? Data,
                          let url = URL(dataRepresentation: urlData, relativeTo: nil) else { return }
                    do {
                        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
                        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
                        DispatchQueue.main.async {
                            self.droppedFileURL = url
                            self.droppedFileSize = size
                        }
                    } catch {
                        DispatchQueue.main.async { self.errorMessage = "Lỗi đọc file." }
                    }
                }
                return true
            }
        }
        return false
    }
    
    private func autoDetectModeIfNeeded() {
        if isLikelyBase64(input) && mode == .encode {
            errorMessage = "Phát hiện chuỗi có vẻ là Base64. Bạn có muốn chuyển sang Decode?"
        } else if !isLikelyBase64(input) && mode == .decode {
            errorMessage = nil
        }
    }
    
    private func isLikelyBase64(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=")
        if trimmed.rangeOfCharacter(from: allowed.inverted) != nil { return false }
        if trimmed.count % 4 != 0 { return false }
        return true
    }
}
