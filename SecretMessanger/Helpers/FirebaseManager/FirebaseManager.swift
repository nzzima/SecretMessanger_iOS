//
//  FirebaseManager.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 28.01.2025.
//

import Foundation
import Firebase
import FirebaseAuth

class FirebaseManager {
    static let shared = FirebaseManager()
    let auth = Auth.auth()
        
    private init() {}
        
    func isLogin() -> Bool {
        return auth.currentUser?.uid == nil ? false : true
    }
        
    func getUser() -> User?{
        guard let user = auth.currentUser else { return nil }
        return user
    }
        
    func signOut() {
        do {
            try auth.signOut()
            NotificationCenter.default.post(name: .windowManager, object: nil, userInfo: [String.state: WindowManager.authorizationWindow])
        } catch {
                print(error.localizedDescription)
        }
    }
}
