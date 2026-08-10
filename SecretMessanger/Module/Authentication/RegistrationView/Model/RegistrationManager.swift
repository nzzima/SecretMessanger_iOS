//
//  RegistrationManager.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 07.08.2026.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

class RegistrationManager {

    private let ref = Firestore.firestore()
    private let registry = LoginRegistry()

    //MARK: Порядок здесь важнее самих шагов. Логин занимается ДО записи профиля,
    // потому что реестр — единственное место, где уникальность действительно
    // проверяется, а правила профиля требуют, чтобы логин уже был занят этим же
    // пользователем. Аккаунт при этом заводится между ними: занимать логин может
    // только вошедший, а `createUser` логинит сразу.
    func createUser(email: String, password: String, login: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        //MARK: Спрашиваем реестр до создания аккаунта — чтобы на занятом логине не
        // оставлять после себя лишнюю запись в Auth. Гонку эта проверка не
        // закрывает: её закрывает `claim` ниже, здесь просто обычный случай.
        registry.check(login: login, uid: nil) { [weak self] result in
            guard let self else { return }

            switch result {
            case .failure(let err):
                completion(.failure(err))
            case .success(.taken), .success(.mine):
                completion(.failure(LoginRegistryError.taken))
            case .success(.free):
                self.createAccount(email: email, password: password, login: login, completion: completion)
            }
        }
    }

    private func createAccount(email: String, password: String, login: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, err in
            if let err {
                completion(.failure(err))
                return
            }

            guard let self, let user = result?.user else {
                completion(.failure(AuthenticationError.noUser))
                return
            }

            self.registry.claim(login: login, uid: user.uid) { err in
                if let err {
                    //MARK: Логин заняли в те доли секунды, что мы создавали аккаунт.
                    // Аккаунт откатываем: без занятого логина правила не дадут
                    // записать профиль, и человек остался бы с учёткой, которой
                    // нельзя пользоваться. Форма после этого чистая — можно просто
                    // ввести другой логин.
                    self.rollback(user: user) {
                        completion(.failure(err))
                    }
                    return
                }

                self.setProfile(uid: user.uid, login: login) { err in
                    if let err {
                        //MARK: Профиль не записался, но логин уже наш — а значит
                        // `ensureProfile` при следующем входе увидит его своим и
                        // допишет профиль с тем же именем. Не держим человека на
                        // экране регистрации из-за поправимого.
                        print("Профиль при регистрации не записался: \(err.localizedDescription)")
                    } else {
                        UserDefaults.standard.set(login, forKey: "selfName")
                    }

                    completion(.success(true))
                }
            }
        }
    }

    //MARK: Если удалить аккаунт не вышло, человек остаётся вошедшим и без профиля.
    // Это не тупик: `ensureProfile` при следующем входе заведёт профиль сам, только
    // логин там будет из префикса почты, а не выбранный.
    private func rollback(user: User, completion: @escaping () -> Void) {
        user.delete { err in
            if let err {
                print("Аккаунт не откатился: \(err.localizedDescription)")
            }

            completion()
        }
    }

    private func setProfile(uid: String, login: String, completion: @escaping (Error?) -> Void) {
        //MARK: Почта сюда не пишется — профили читает любой вошедший, а адрес и так
        // хранится в Firebase Auth. См. комментарий в AuthenticationManager.
        ref
            .collection(.users)
            .document(uid)
            .setData([
                "login": login,
                "name": login,
                "someInfo": ""
            ]) { err in
                completion(err)
            }
    }
}
