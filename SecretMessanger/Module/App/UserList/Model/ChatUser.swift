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

    //MARK: Открытая половина постоянного ключа, в base64. Носится вместе с контактом,
    // потому что нужна ровно там, где контакт выбирают: заводя чат или добавляя
    // человека в группу, создатель тут же запечатывает для него ключ диалога.
    // Пустая — значит человек не заходил после появления шифрования.
    var publicKey: String

    //MARK: Версия аватара — картинка лежит отдельно, в `avatars/{uid}`. Едет вместе с
    // контактом по той же причине, что и открытый ключ: она нужна ровно там, где
    // контакт показывают, а лишний поход в профиль на каждую ячейку списка дорог.
    var avatarVersion: Int

    init(id: String, login: String, publicKey: String = "", avatarVersion: Int = 0) {
        self.id = id
        self.login = login
        self.publicKey = publicKey
        self.avatarVersion = avatarVersion
    }

    init(id: String, userInfo: [String: Any]) {
        self.id = id

        let login = userInfo["login"] as? String ?? ""
        let name = userInfo["name"] as? String ?? ""
        self.login = login.isEmpty ? name : login
        self.publicKey = userInfo["publicKey"] as? String ?? ""
        self.avatarVersion = userInfo["avatarVersion"] as? Int ?? 0
    }
}
