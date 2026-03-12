import Foundation
import AppKit

struct DropHandler {
    static func handleTextDrop(providers: [NSItemProvider], completion: @escaping (String) -> Void) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.utf8-plain-text") {
                _ = provider.loadObject(ofClass: NSString.self) { item, _ in
                    if let text = item as? String {
                        DispatchQueue.main.async { completion(text) }
                    }
                }
                return true
            } else if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                _ = provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (urlData, _) in
                    guard
                        let urlData = urlData as? Data,
                        let url = URL(dataRepresentation: urlData, relativeTo: nil)
                    else { return }
                    if let content = try? String(contentsOf: url, encoding: .utf8) {
                        DispatchQueue.main.async { completion(content) }
                    }
                }
                return true
            }
        }
        return false
    }
}
