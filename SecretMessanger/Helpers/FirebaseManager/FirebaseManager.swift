//
//  FirebaseManager.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 28.01.2025.
//

import Foundation
import Firebase
import FirebaseAuth

/// Тонкая обёртка над Firebase Auth: кто вошёл и как выйти.
class FirebaseManager {
    static let shared = FirebaseManager()
    let auth = Auth.auth()
        
    private init() {}
        
    /// Есть ли действующая сессия. Она живёт месяцами и переживает перезапуск.
    func isLogin() -> Bool {
        return auth.currentUser?.uid == nil ? false : true
    }
        
    /// Вошедший пользователь; его `uid` — это id документа профиля и половина id диалога.
    func getUser() -> User?{
        guard let user = auth.currentUser else { return nil }
        return user
    }
        
    /// Выходит из аккаунта и просит окно смениться на экран входа.
    func signOut() {
        do {
            //MARK: Пульс останавливается до выхода, а не после: правило разрешает писать
            // присутствие только себе, и удар, догнавший уже разлогиненное приложение,
            // просто отвалился бы с ошибкой в консоль.
            PresenceStore.shared.deactivate()

            try auth.signOut()
            NotificationCenter.default.post(name: .windowManager, object: nil, userInfo: [String.state: WindowManager.authorizationWindow])
        } catch {
                print(error.localizedDescription)
        }
    }
}
