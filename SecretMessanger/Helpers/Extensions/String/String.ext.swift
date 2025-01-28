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

//MARK: UserInfo keys
extension String {
    static let state = "state"
}
