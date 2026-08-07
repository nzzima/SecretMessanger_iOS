//
//  ProfileManager.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 24.02.2025.
//

import Foundation
import Firebase
import FirebaseFirestore

class ProfileManager {

    private let ref = Firestore.firestore()
    private var listener: ListenerRegistration?

    //MARK: Профиль лежит в users/{uid}, поэтому читаем один документ вместо того,
    // чтобы тянуть всю коллекцию и искать себя перебором. Слушатель здесь по делу:
    // экран должен показывать изменения профиля сразу после сохранения.
    func getActiveUser(completion: @escaping ([String]) -> Void) {
        guard let uid = FirebaseManager.shared.getUser()?.uid else { return }

        listener?.remove()

        listener = ref
            .collection(.users)
            .document(uid)
            .addSnapshotListener { snap, err in
                if let err {
                    print("Профиль не загрузился: \(err.localizedDescription)")
                    return
                }

                guard let userData = snap?.data() else { return }

                let user = ActiveUser(id: uid, userInfo: userData)

                completion([user.id, user.login, user.name, user.someInfo])
            }
    }

    func stopObserving() {
        listener?.remove()
        listener = nil
    }
}
