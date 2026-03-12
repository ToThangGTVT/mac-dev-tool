import Foundation

@Observable
class Base64ViewModel {
    var mode: Base64Mode {
        didSet { 
            UserDefaults.standard.set(mode.rawValue, forKey: "base64.mode")
            performMainAction() 
        }
    }
    var wrap: Base64Wrap {
        didSet { 
            UserDefaults.standard.set(wrap.rawValue, forKey: "base64.wrap")
            performMainAction() 
        }
    }
    var lineEnding: Base64LineEnding {
        didSet { 
            UserDefaults.standard.set(lineEnding.rawValue, forKey: "base64.lineEnding")
            performMainAction() 
        }
    }
    var stringEncoding: TextEncoding {
        didSet { 
            UserDefaults.standard.set(stringEncoding.rawValue, forKey: "base64.encoding")
            performMainAction() 
        }
    }
    
    var input: String = "" {
        didSet { 
            if input != oldValue {
                autoDetectModeIfNeeded()
                performMainAction() 
            }
        }
    }
    var output: String = ""
    var errorMessage: String?
    
    init() {
        self.mode = Base64Mode(rawValue: UserDefaults.standard.string(forKey: "base64.mode") ?? "") ?? .encode
        self.wrap = Base64Wrap(rawValue: UserDefaults.standard.string(forKey: "base64.wrap") ?? "") ?? .none
        self.lineEnding = Base64LineEnding(rawValue: UserDefaults.standard.string(forKey: "base64.lineEnding") ?? "") ?? .lf
        self.stringEncoding = TextEncoding(rawValue: UserDefaults.standard.string(forKey: "base64.encoding") ?? "") ?? .utf8
    }
    
    func performMainAction() {
        errorMessage = nil
        output = ""
        
        switch mode {
        case .encode:
            guard let data = input.data(using: stringEncoding.nsEncoding) else {
                errorMessage = "Không thể chuyển input sang dữ liệu với encoding \(stringEncoding.rawValue)."
                return
            }
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
            guard let data = Data(base64Encoded: input, options: .ignoreUnknownCharacters) else {
                errorMessage = "Input không phải Base64 hợp lệ."
                return
            }
            if let str = String(data: data, encoding: stringEncoding.nsEncoding) {
                output = str
            } else if let utf8 = String(data: data, encoding: .utf8) {
                output = utf8
                errorMessage = "Không decode được với \(stringEncoding.rawValue). Đã fallback UTF-8."
            } else {
                errorMessage = "Không thể chuyển dữ liệu đã decode thành chuỗi văn bản."
            }
        }
    }
    
    func swapMode() {
        mode = (mode == .encode) ? .decode : .encode
        output = ""
        errorMessage = nil
    }
    
    func clearAll() {
        input = ""
        output = ""
        errorMessage = nil
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
