//
//  String.ext.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 28.01.2025.
//

import Foundation

extension String {
    static func locolize(_ text: String.LocalizationValue) -> String {
        String(localized: text)
    }
}

extension String {
    static let state = "state"
}

extension String {
    static let users = "users"
    static let logins = "logins"
    static let conversation = "conversation"
    static let messages = "messages"
    static let audio = "audio"
    static let images = "images"
}

extension String {
    func truncate(to limit: Int, ellipsis: Bool = true) -> String {
        if count > limit {
            let truncated = String(prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines)
            
            return ellipsis ? truncated + "\u{2026}" : truncated
        } else {
            return self
        }
    }
}
