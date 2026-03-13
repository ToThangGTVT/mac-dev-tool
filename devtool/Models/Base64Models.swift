import Foundation

enum Base64Mode: String, CaseIterable, Identifiable {
    case encode = "Encode"
    case decode = "Decode"
    var id: String { rawValue }
}

enum UnifiedAlgorithm: String, CaseIterable, Identifiable {
    case base64 = "Base64"
    case md5    = "MD5"
    case sha1   = "SHA-1"
    case sha256 = "SHA-256"
    case sha384 = "SHA-384"
    case sha512 = "SHA-512"
    var id: String { rawValue }
    
    var isHash: Bool {
        self != .base64
    }
}

enum Base64Wrap: String, CaseIterable, Identifiable {
    case none = "None"
    case w64  = "64"
    case w76  = "76"
    var id: String { rawValue }
}

enum Base64LineEnding: String, CaseIterable, Identifiable {
    case lf   = "LF (\\n)"
    case crlf = "CRLF (\\r\\n)"
    var id: String { rawValue }
}

