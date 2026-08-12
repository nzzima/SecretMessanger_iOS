//
//  UserProfileManager.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 21.02.2025.
//

import Foundation
import FirebaseFirestore

/// Профиль собеседника — один документ, а не вся коллекция.
class UserProfileManager {

    private let ref = Firestore.firestore()
    private var listener: ListenerRegistration?

    //MARK: Слушаем один документ, а не всю коллекцию users: профиль обновится, если
    // собеседник поменяет имя или заметку, и при этом не тянем чужие профили.
    /// Слушает профиль конкретного человека: сменит имя или заметку — экран обновится.
    func observeProfile(userId: String, completion: @escaping (Result<ProfileInfo, Error>) -> Void) {
        listener?.remove()

        listener = ref
            .collection(.users)
            .document(userId)
            .addSnapshotListener { snap, err in
                if let err {
                    completion(.failure(err))
                    return
                }

                guard let data = snap?.data() else { return }

                completion(.success(ProfileInfo(data: data)))
            }
    }

    /// Снимает слушатель.
    func stopObserving() {
        listener?.remove()
        listener = nil
    }
}
