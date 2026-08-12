//
//  ActiveUserInfo.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 24.02.2025.
//

import Foundation

/// Собственный профиль владельца устройства — то, что показывает вкладка «Профиль».
struct ActiveUser {
    var id: String
    var login: String
    var name: String
    var someInfo: String

    //MARK: Номер версии аватара, а не сама картинка: байты лежат в `avatars/{uid}`,
    // см. AvatarStore. Ноль — аватара нет, и в базу за ним никто не пойдёт.
    var avatarVersion: Int

    init(id: String, userInfo: [String: Any]) {
        let name = userInfo["name"] as? String ?? ""
        let login = userInfo["login"] as? String ?? ""

        self.id = id
        self.name = name
        self.someInfo = userInfo["someInfo"] as? String ?? ""
        self.login = login.isEmpty ? name : login
        self.avatarVersion = userInfo["avatarVersion"] as? Int ?? 0
    }
}
