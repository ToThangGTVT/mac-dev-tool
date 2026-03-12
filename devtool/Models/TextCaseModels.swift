import Foundation

enum TextCaseMode: String, CaseIterable, Identifiable {
    case lower = "lowercase"
    case upper = "UPPERCASE"
    case sentence = "Sentence case"
    case title = "Title Case"
    case capitalize = "Capitalize Words"
    case inverse = "Inverse Case"
    case alternating = "aLtErNaTiNg cAsE"
    case camel = "camelCase"
    case pascal = "PascalCase"
    case snake = "snake_case"
    case kebab = "kebab-case"
    case constant = "CONSTANT_CASE"
    case slug = "slugify"
    
    var id: String { rawValue }
}
