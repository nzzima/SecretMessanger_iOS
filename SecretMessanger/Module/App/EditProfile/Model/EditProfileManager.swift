//
//  EditProfileManager.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 27.02.2025.
//

import Foundation
import Firebase
import FirebaseFirestore

class EditProfileManager {
    private let ref = Firestore.firestore()
    
    func getActiveUserName(completion: @escaping (String) -> Void) {
        ref
            .collection(.users)
            
            //MARK: default: .getDocuments (or .addSnapshotListener - to imedietly update database changed info about users (add, delete, change userInfo) by Firebase changing)
        
            .addSnapshotListener { snap, err in
                guard err == nil else { return }
                guard let docs = snap?.documents else { return }
                
                var activeUserName: String = ""
                docs.forEach { user in
                    let userData = user.data()
                    if FirebaseManager.shared.getUser()?.uid == user.documentID {
                        let user = ActiveUser(id: user.documentID, userInfo: userData)
                        activeUserName = user.name
                    }
                }
                completion(activeUserName)
            }
    }
    
    func getActiveUserSomeInfo(completion: @escaping (String) -> Void) {
        ref
            .collection(.users)
            
            //MARK: default: .getDocuments (or .addSnapshotListener - to imedietly update database changed info about users (add, delete, change userInfo) by Firebase changing)
        
            .addSnapshotListener { snap, err in
                guard err == nil else { return }
                guard let docs = snap?.documents else { return }
                
                var activeUserSomeInfo: String = ""
                docs.forEach { user in
                    let userData = user.data()
                    if FirebaseManager.shared.getUser()?.uid == user.documentID {
                        let user = ActiveUser(id: user.documentID, userInfo: userData)
                        activeUserSomeInfo = user.someInfo
                    }
                }
                completion(activeUserSomeInfo)
            }
    }
}
