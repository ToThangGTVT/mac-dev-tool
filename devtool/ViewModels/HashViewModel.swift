import Foundation
import CryptoKit

@Observable
class HashViewModel {
    var algorithm: HashAlgorithm {
        didSet { 
            UserDefaults.standard.set(algorithm.rawValue, forKey: "hash.algorithm")
            if autoUpdate { computeHash() }
        }
    }
    var outputFormat: HashOutputFormat {
        didSet { 
            UserDefaults.standard.set(outputFormat.rawValue, forKey: "hash.outputFormat")
            if autoUpdate { computeHash() }
        }
    }
    var stringEncoding: TextEncoding {
        didSet { 
            UserDefaults.standard.set(stringEncoding.rawValue, forKey: "hash.encoding")
            if autoUpdate && droppedFileURL == nil { computeHash() }
        }
    }
    var autoUpdate: Bool {
        didSet {
            UserDefaults.standard.set(autoUpdate, forKey: "hash.autoUpdate")
            if autoUpdate { computeHash() }
        }
    }
    
    var input: String = "" {
        didSet {
            if input != oldValue && autoUpdate && droppedFileURL == nil { computeHash() }
        }
    }
    
    var output: String = ""
    var errorMessage: String?
    
    var droppedFileURL: URL? {
        didSet {
            if autoUpdate && droppedFileURL != nil { computeHash() }
        }
    }
    var droppedFileSize: Int64 = 0
    
    init() {
        self.algorithm = HashAlgorithm(rawValue: UserDefaults.standard.string(forKey: "hash.algorithm") ?? "") ?? .sha256
        self.outputFormat = HashOutputFormat(rawValue: UserDefaults.standard.string(forKey: "hash.outputFormat") ?? "") ?? .hexLower
        self.stringEncoding = TextEncoding(rawValue: UserDefaults.standard.string(forKey: "hash.encoding") ?? "") ?? .utf8
        
        if UserDefaults.standard.object(forKey: "hash.autoUpdate") == nil {
            self.autoUpdate = true
        } else {
            self.autoUpdate = UserDefaults.standard.bool(forKey: "hash.autoUpdate")
        }
    }
    
    func computeHash() {
        errorMessage = nil
        output = ""
        
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
        
        let digestBytes: [UInt8]
        switch algorithm {
        case .md5:    digestBytes = Array(Insecure.MD5.hash(data: data))
        case .sha1:   digestBytes = Array(Insecure.SHA1.hash(data: data))
        case .sha256: digestBytes = Array(SHA256.hash(data: data))
        case .sha384: digestBytes = Array(SHA384.hash(data: data))
        case .sha512: digestBytes = Array(SHA512.hash(data: data))
        }
        
        switch outputFormat {
        case .hexLower:
            output = digestBytes.map { String(format: "%02x", $0) }.joined()
        case .hexUpper:
            output = digestBytes.map { String(format: "%02X", $0) }.joined()
        case .base64:
            output = Data(digestBytes).base64EncodedString()
        }
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
                _ = provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (urlData, _) in
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
            if provider.hasItemConformingToTypeIdentifier("public.utf8-plain-text") {
                _ = provider.loadObject(ofClass: NSString.self) { item, _ in
                    if let text = item as? String {
                        DispatchQueue.main.async {
                            self.removeDroppedFile()
                            self.input = text
                        }
                    }
                }
                return true
            }
        }
        return false
    }
}
