//
//  SelfName.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 10.08.2026.
//

import Foundation

//MARK: Свой логин, чтобы не читать профиль ради подписи под собственным сообщением.
//
// Раньше это была строка `"selfName"`, набранная руками в пяти местах. Пока значение
// только читали, это сходило с рук; с появлением смены логина его стало нужно ещё и
// обновлять — а опечатка в ключе на записи означала бы, что человек переименовался, а
// подписывается по-старому, и понять почему было бы нечем.
enum SelfName {

    private static let key = "selfName"

    static var current: String {
        get { UserDefaults.standard.string(forKey: key) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
