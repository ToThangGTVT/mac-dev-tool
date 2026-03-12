import Foundation

extension Data {
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
