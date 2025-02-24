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
