//
//  ActiveUserInfo.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 24.02.2025.
//

import Foundation

struct ActiveUser {
    var id: String
    var login: String
    var name: String
    var someInfo: String

    init(id: String, userInfo: [String: Any]) {
        let name = userInfo["name"] as? String ?? ""
        let login = userInfo["login"] as? String ?? ""

        self.id = id
        self.name = name
        self.someInfo = userInfo["someInfo"] as? String ?? ""
        self.login = login.isEmpty ? name : login
    }
}
