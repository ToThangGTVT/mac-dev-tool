import Foundation

enum Base64Mode: String, CaseIterable, Identifiable {
    case encode = "Encode"
    case decode = "Decode"
    var id: String { rawValue }
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
