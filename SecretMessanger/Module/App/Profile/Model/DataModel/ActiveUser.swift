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
        self.id = id
        self.login = userInfo["login"] as? String ?? ""
        self.name = userInfo["name"] as? String ?? ""
        self.someInfo = userInfo["someInfo"] as? String ?? ""
    }
}

extension ActiveUser {
    subscript(key: String) -> String? {
        switch key {
            case "id": return id
            case "login": return login
            case "name": return name
            case "someInfo": return someInfo
            default: return nil
        }
    }
}
