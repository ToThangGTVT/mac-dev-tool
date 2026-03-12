import Foundation
import Security

enum RSAOperation: String, CaseIterable, Identifiable {
    case encrypt = "Encrypt"
    case decrypt = "Decrypt"
    case sign    = "Sign"
    case verify  = "Verify"
    var id: String { rawValue }
}

enum RSABinaryFormat: String, CaseIterable, Identifiable {
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

enum RSAKeySize: Int, CaseIterable, Identifiable {
    case bits2048 = 2048
    case bits3072 = 3072
    case bits4096 = 4096
    var id: Int { rawValue }
    var label: String { "\(rawValue) bits" }
}
