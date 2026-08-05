//
//  ChatUser.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 31.01.2025.
//

import Foundation

struct ChatUser {
    var id: String
    var login: String

    init(id: String, userInfo: [String: Any]) {
        self.id = id

        let login = userInfo["login"] as? String ?? ""
        let name = userInfo["name"] as? String ?? ""
        self.login = login.isEmpty ? name : login
    }
}
