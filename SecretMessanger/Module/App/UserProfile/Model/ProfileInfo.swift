//
//  ProfileInfo.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 21.02.2025.
//

import Foundation

//MARK: Публичная часть профиля — то, что видно любому собеседнику. `email` из
// документа users/{uid} сюда намеренно не попадает: это личные контактные данные,
// их не показывает даже собственный профиль. Uid тоже не выносим — для чужого
// профиля это технический шум. Поле добавляется сюда только осознанно.
struct ProfileInfo {
    var login: String
    var name: String
    var someInfo: String

    init(data: [String: Any]) {
        let login = data["login"] as? String ?? ""
        let name = data["name"] as? String ?? ""

        self.name = name
        self.login = login.isEmpty ? name : login
        self.someInfo = data["someInfo"] as? String ?? ""
    }
}
