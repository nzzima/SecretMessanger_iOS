//
//  LoginRegistry.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 10.08.2026.
//

import Foundation
import FirebaseFirestore

enum LoginAvailability {
    case free
    case mine
    case taken
}

enum LoginRegistryError: LocalizedError {
    case taken

    var errorDescription: String? {
        switch self {
        case .taken:
            return "Логин уже занят — выберите другой"
        }
    }
}

//MARK: Реестр занятых логинов: коллекция `logins`, по документу на логин, id
// документа — логин в нижнем регистре. Регистр в ключ не попадает намеренно: иначе
// `red` и `Red` были бы разными именами, и уникальность распадалась бы ровно на
// похожих написаниях, ради которых она и заводится.
//
// Уникальность держит не этот класс, а правило Firestore: `create` по уже
// существующему документу запрещён. Проверка `check` — вежливость к обычному
// случаю, чтобы не заводить аккаунт под заведомо занятое имя; гонку двух
// одновременных регистраций закрывает только сама запись.
class LoginRegistry {

    private let ref = Firestore.firestore()

    static func key(for login: String) -> String {
        login.lowercased()
    }

    //MARK: Логин участвует в правилах как ключ документа, поэтому мусор в нём
    // означал бы профиль, который невозможно записать. Префикс почты приходит с
    // точками и плюсами — вычищаем до того же набора, что требует `FieldValidator`.
    static func sanitize(_ raw: String, uid: String) -> String {
        let allowed = raw.filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }
        let base = String(allowed.prefix(20))

        return base.count >= 3 ? base : "user_" + uid.prefix(6).lowercased()
    }

    static func isTaken(_ error: Error) -> Bool {
        let error = error as NSError

        //MARK: Занятый логин приходит именно отказом правил: документ существует, а
        // `update` для реестра запрещён. Отличать его от обрыва связи обязательно —
        // на «занято» регистрация откатывает аккаунт, на сетевую ошибку не должна.
        return error.domain == FirestoreErrorDomain
            && error.code == FirestoreErrorCode.permissionDenied.rawValue
    }

    func check(login: String, uid: String?, completion: @escaping (Result<LoginAvailability, Error>) -> Void) {
        ref
            .collection(.logins)
            .document(LoginRegistry.key(for: login))
            .getDocument { snap, err in
                if let err {
                    completion(.failure(err))
                    return
                }

                guard let snap, snap.exists else {
                    completion(.success(.free))
                    return
                }

                let owner = snap.data()?["uid"] as? String
                completion(.success(owner == uid ? .mine : .taken))
            }
    }

    func claim(login: String, uid: String, completion: @escaping (Error?) -> Void) {
        //MARK: `setData` без merge: по существующему документу это `update`, а он в
        // реестре запрещён правилом. То есть занять чужое нельзя даже случайно.
        ref
            .collection(.logins)
            .document(LoginRegistry.key(for: login))
            .setData(["uid": uid, "login": login]) { err in
                completion(err)
            }
    }

    //MARK: Освободить занятый логин. Вызывается последним шагом переименования: пока
    // новое имя не занято и не записано в профиль, отпускать старое нельзя — сорвись
    // что-нибудь посередине, человек остался бы без обоих, а имя успел бы забрать
    // кто-то другой.
    func release(login: String, completion: @escaping (Error?) -> Void) {
        ref
            .collection(.logins)
            .document(LoginRegistry.key(for: login))
            .delete { err in
                completion(err)
            }
    }

    //MARK: Занять предпочтительный логин, а если его успели забрать — соседний с
    // хвостом из uid. Нужно там, где спросить человека уже нельзя: профиль без
    // занятого логина правила записать не дадут, а вход из-за этого ронять нельзя.
    func claimAvailable(preferred: String, uid: String, completion: @escaping (Result<String, Error>) -> Void) {
        let preferred = LoginRegistry.sanitize(preferred, uid: uid)
        let fallback = String(preferred.prefix(15)) + "_" + uid.prefix(4).lowercased()

        claimOrFail(login: preferred, uid: uid) { [weak self] result in
            switch result {
            case .success:
                completion(.success(preferred))
            case .failure(let err) where LoginRegistry.isTaken(err) || err is LoginRegistryError:
                self?.claimOrFail(login: fallback, uid: uid) { result in
                    completion(result.map { fallback })
                }
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }

    private func claimOrFail(login: String, uid: String, completion: @escaping (Result<Void, Error>) -> Void) {
        check(login: login, uid: uid) { [weak self] result in
            switch result {
            case .failure(let err):
                completion(.failure(err))
            case .success(.mine):
                //MARK: Логин уже наш — переписывать документ не нужно, да и нечем:
                // `update` реестра запрещён всем.
                completion(.success(()))
            case .success(.taken):
                completion(.failure(LoginRegistryError.taken))
            case .success(.free):
                self?.claim(login: login, uid: uid) { err in
                    if let err {
                        completion(.failure(err))
                    } else {
                        completion(.success(()))
                    }
                }
            }
        }
    }
}
