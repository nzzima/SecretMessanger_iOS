//
//  ProfileInfo.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 21.02.2025.
//

import Foundation

/// Публичная часть чужого профиля — то, что человек сам заполняет для показа.
///
/// Граница проходит здесь, по модели, а не по вёрстке: `email` из документа
/// `users/{uid}` сюда намеренно не попадает — это личные контактные данные, их не
/// показывает даже собственный профиль. Uid тоже не выносим: для чужого профиля это
/// технический шум. Поле добавляется сюда только осознанно.
struct ProfileInfo {
    var login: String
    var name: String
    var someInfo: String

    //MARK: Аватар публичен по своей природе — его видно и в контактах, и в бабблах
    // переписки, — так что версия картинки в этот список попадает без оговорок.
    var avatarVersion: Int

    init(data: [String: Any]) {
        let login = data["login"] as? String ?? ""
        let name = data["name"] as? String ?? ""

        self.name = name
        self.login = login.isEmpty ? name : login
        self.someInfo = data["someInfo"] as? String ?? ""
        self.avatarVersion = data["avatarVersion"] as? Int ?? 0
    }
}
