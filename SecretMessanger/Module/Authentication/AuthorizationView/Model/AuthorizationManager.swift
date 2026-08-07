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
    // профиля. Пока нет экрана регистрации, это единственное место, где профиль заводится.
    private func ensureProfile(for user: User, completion: @escaping (Result<String, Error>) -> Void) {
        let document = ref.collection(.users).document(user.uid)

        document.getDocument { snap, err in
            if let err {
                completion(.failure(err))
                return
            }

            let stored = snap?.data() ?? [:]
            let email = user.email ?? ""

            func field(_ key: String) -> String {
                stored[key] as? String ?? ""
            }

            let name = field("name").isEmpty ? (email.components(separatedBy: "@").first ?? "") : field("name")
            let login = field("login").isEmpty ? name : field("login")

            //MARK: Почта сюда не пишется. Профили читает любой вошедший — так устроен
            // список контактов, — а `email` при этом не нужен ни одному экрану:
            // `ProfileInfo` его намеренно не показывает. В Firestore он лежал бы
            // открытым без всякой пользы; адрес и так есть в Firebase Auth.
            let profile: [String: Any] = [
                "login": login,
                "name": name,
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
