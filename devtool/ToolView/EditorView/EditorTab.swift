//
//  EditorTab.swift
//  devtool
//

import Foundation

struct EditorTab: Identifiable, Codable {
    let id: UUID
    var text: String = ""
    var fileURL: URL?
    var savingState: NotePadEditor.SavingState = .idle
    var lastError: String? = nil

    enum CodingKeys: String, CodingKey {
        case id, fileURL
    }

    var title: String {
        if let url = fileURL {
            if url.path.contains("/Drafts/") { return "Untitled" }
            return url.lastPathComponent
        }
        return "Untitled"
    }

    init(id: UUID = UUID(), text: String = "", fileURL: URL? = nil) {
        self.id          = id
        self.text        = text
        self.fileURL     = fileURL
        self.savingState = .idle
        self.lastError   = nil
    }
}
