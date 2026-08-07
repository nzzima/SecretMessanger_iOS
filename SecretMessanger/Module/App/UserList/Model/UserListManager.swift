//
//  UserListManager.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 21.02.2025.
//

import Foundation
import Firebase
import FirebaseFirestore

class UserListManager {
    private let ref = Firestore.firestore()
    private var listener: ListenerRegistration?

    func getAllUsers(completion: @escaping ([ChatUser]) -> Void) {
        listener?.remove()

        listener = ref
            .collection(.users)

            //MARK: default: .getDocuments (or .addSnapshotListener - to imedietly update database changed info about users (add, delete, change userInfo) by Firebase changing)
            .addSnapshotListener { snap, err in
                guard err == nil else { return }
                guard let docs = snap?.documents else { return }

                var users: [ChatUser] = []
                docs.forEach { user in
                    let userData = user.data()
                    if FirebaseManager.shared.getUser()?.uid != user.documentID {
                        let user = ChatUser(id: user.documentID, userInfo: userData)
                        users.append(user)
                    }
                }
                completion(users)
            }
    }

    func stopObserving() {
        listener?.remove()
        listener = nil
    }
}
