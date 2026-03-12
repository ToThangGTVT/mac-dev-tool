import Foundation

struct RegexMatchInfo {
    let range: NSRange
    let substring: String
    let groups: [RegexGroupInfo]
}

struct RegexGroupInfo {
    let index: Int
    let name: String?
    let range: NSRange
    let value: String?
}
