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

    //MARK: Здесь висели два слушателя на всю коллекцию `users` — по одному на каждое
    // поле одного и того же документа, и ни один не отцеплялся. Форме редактирования
    // живые обновления не нужны: свой документ читается один раз, при открытии.
    func getActiveUser(completion: @escaping (_ name: String, _ someInfo: String) -> Void) {
        guard let uid = FirebaseManager.shared.getUser()?.uid else { return }

        ref
            .collection(.users)
            .document(uid)
            .getDocument { snap, err in
                if let err {
                    print("Профиль не загрузился: \(err.localizedDescription)")
                    return
                }

                guard let userData = snap?.data() else { return }

                let user = ActiveUser(id: uid, userInfo: userData)

                completion(user.name, user.someInfo)
            }
    }
}
