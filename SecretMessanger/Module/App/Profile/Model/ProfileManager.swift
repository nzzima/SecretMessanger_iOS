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
    //MARK: Отдаём `ActiveUser`, а не массив `[id, login, name, someInfo]`, как было
    // раньше: порядок элементов был неявным договором менеджера с экраном, и
    // перестановка двух строк тихо меняла бы подписи на чужие значения. Модель для
    // этого и заведена.
    /// Слушает **свой** документ профиля — не всю коллекцию.
    ///
    /// Живые обновления здесь по делу: правку в другом месте (или смену аватара) экран
    /// показывает без перезахода.
    func getActiveUser(completion: @escaping (ActiveUser) -> Void) {
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

                completion(ActiveUser(id: uid, userInfo: userData))
            }
    }

    /// Снимает слушатель.
    func stopObserving() {
        listener?.remove()
        listener = nil
    }
}
