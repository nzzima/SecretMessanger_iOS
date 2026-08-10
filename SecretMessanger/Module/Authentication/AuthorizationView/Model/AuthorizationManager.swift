//
//  AuthorizationManager.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 31.01.2025.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

enum AuthenticationError: LocalizedError {
    case noUser

    var errorDescription: String? {
        switch self {
        case .noUser:
            return "Не удалось получить пользователя после входа"
        }
    }
}

class AuthenticationManager {

    private let ref = Firestore.firestore()
    private let registry = LoginRegistry()

    func auth(userInfo: UserInfo, completion: @escaping (Result<Bool, Error>) -> Void) {
        Auth.auth().signIn(withEmail: userInfo.email, password: userInfo.password) { [weak self] result, err in
            if let err {
                completion(.failure(err))
                return
            }

            guard let self, let user = result?.user else {
                completion(.failure(AuthenticationError.noUser))
                return
            }

            self.ensureProfile(for: user) { result in
                switch result {
                case .success(let login):
                    UserDefaults.standard.set(login, forKey: "selfName")
                case .failure(let err):
                    //MARK: Вход уже состоялся — Firestore подтягивается позже, чем Auth,
                    // и первый запрос после запуска может упасть в «client is offline».
                    // Не держим пользователя на экране входа из-за профиля: он
                    // допишется при следующем входе.
                    print("Профиль не синхронизирован: \(err.localizedDescription)")
                }

                completion(.success(true))
            }
        }
    }

    //MARK: Профиль лежит в users/{uid} — id документа обязан совпадать с uid из Auth.
    // На этом держится и фильтр «не показывать себя» в контактах, и поиск собственного
    // профиля. Профиль заводит экран регистрации, а этот метод чинит всё, что мимо
    // него: аккаунты из консоли, регистрацию, оборвавшуюся на записи профиля,
    // и логины, заведённые до появления реестра.
    private func ensureProfile(for user: User, completion: @escaping (Result<String, Error>) -> Void) {
        let document = ref.collection(.users).document(user.uid)

        document.getDocument { [weak self] snap, err in
            if let err {
                completion(.failure(err))
                return
            }

            guard let self else { return }

            let stored = snap?.data() ?? [:]
            let email = user.email ?? ""

            func field(_ key: String) -> String {
                stored[key] as? String ?? ""
            }

            let name = field("name").isEmpty ? (email.components(separatedBy: "@").first ?? "") : field("name")
            let preferred = field("login").isEmpty ? name : field("login")

            //MARK: Логин обязан быть занят в реестре: правила профиля этого требуют,
            // иначе запись ниже просто не пройдёт. Один лишний чтение-запрос на вход —
            // плата за то, что старые профили доедут до реестра сами, без миграции.
            //
            // Занят кем-то другим — берём соседнее имя с хвостом из uid. Молчаливое
            // переименование выглядит грубо, но выбор здесь между ним и профилем,
            // который невозможно записать: до реестра два аккаунта могли взять один
            // логин, и кто-то из них теперь обязан подвинуться.
            self.registry.claimAvailable(preferred: preferred, uid: user.uid) { result in
                switch result {
                case .failure(let err):
                    completion(.failure(err))
                case .success(let login):
                    //MARK: Почта сюда не пишется. Профили читает любой вошедший — так
                    // устроен список контактов, — а `email` при этом не нужен ни одному
                    // экрану: `ProfileInfo` его намеренно не показывает. В Firestore он
                    // лежал бы открытым без всякой пользы; адрес и так есть в Auth.
                    let profile: [String: Any] = [
                        "login": login,
                        "name": name.isEmpty ? login : name,
                        "someInfo": field("someInfo")
                    ]

                    document.setData(profile, merge: true) { err in
                        if let err {
                            completion(.failure(err))
                        } else {
                            completion(.success(login))
                        }
                    }
                }
            }
        }
    }
}
