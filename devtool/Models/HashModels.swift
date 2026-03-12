import Foundation

enum HashAlgorithm: String, CaseIterable, Identifiable {
    case md5 = "MD5"
    case sha1 = "SHA-1"
    case sha256 = "SHA-256"
    case sha384 = "SHA-384"
    case sha512 = "SHA-512"
    var id: String { rawValue }
}

enum HashOutputFormat: String, CaseIterable, Identifiable {
    case hexLower = "Hex (lowercase)"
    case hexUpper = "Hex (UPPERCASE)"
    case base64   = "Base64"
    var id: String { rawValue }
}
