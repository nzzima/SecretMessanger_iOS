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
    //private var lastDoc: DocumentSnapshot?
        
    func getActiveUser(completion: @escaping ([String]) -> Void) {
        ref
            .collection(.users)
            
            //MARK: default: .getDocuments (or .addSnapshotListener - to imedietly update database changed info about users (add, delete, change userInfo) by Firebase changing)
            .addSnapshotListener { snap, err in
                guard err == nil else { return }
                guard let docs = snap?.documents else { return }
                
                var activeUser: [String] = []
                docs.forEach { user in
                    let userData = user.data()
                    if FirebaseManager.shared.getUser()?.uid == user.documentID {
                        let user = ActiveUser(id: user.documentID, userInfo: userData)
                        activeUser.append(user.id)
                        activeUser.append(user.login)
                        activeUser.append(user.name)
                        activeUser.append(user.someInfo)
                    }
                }
                completion(activeUser)
            }
    }
}
