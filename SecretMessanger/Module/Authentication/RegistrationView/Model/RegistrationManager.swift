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

    func createUser(email: String, password: String, login: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, err in
            if let err {
                completion(.failure(err))
                return
            }

            guard let self, let user = result?.user else {
                completion(.failure(AuthenticationError.noUser))
                return
            }

            //MARK: `createUser` сразу логинит нового пользователя, поэтому запись в
            // users/{uid} проходит правила Firestore: id документа равен uid вошедшего.
            self.setProfile(uid: user.uid, login: login) { err in
                if let err {
                    //MARK: Аккаунт в Auth уже создан, и повторная регистрация упрётся в
                    // «email занят». Не держим человека на экране: профиль допишет
                    // `AuthenticationManager.ensureProfile` при следующем входе, только
                    // логин там возьмётся из префикса почты.
                    print("Профиль при регистрации не записался: \(err.localizedDescription)")
                } else {
                    UserDefaults.standard.set(login, forKey: "selfName")
                }

                completion(.success(true))
            }
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
