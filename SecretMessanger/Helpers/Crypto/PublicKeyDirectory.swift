//
//  PublicKeyDirectory.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 10.08.2026.
//

import Foundation
import FirebaseFirestore

//MARK: Открытые ключи участников лежат в `users`, а не в шапке диалога, — дублировать
// их туда незачем, они и так публичные. Читают их два места: создание чата и правка
// состава, поэтому чтение вынесено сюда, а не размножено по менеджерам.
enum PublicKeyDirectory {

    static func keys(for uids: [String], completion: @escaping ([String: String]) -> Void) {
        guard !uids.isEmpty else {
            completion([:])
            return
        }

        let ref = Firestore.firestore()
        let group = DispatchGroup()
        let lock = NSLock()
        var keys: [String: String] = [:]

        uids.forEach { uid in
            group.enter()

            ref.collection(.users).document(uid).getDocument { snap, _ in
                defer { group.leave() }

                guard let key = snap?.data()?["publicKey"] as? String, !key.isEmpty else { return }

                lock.lock()
                keys[uid] = key
                lock.unlock()
            }
        }

        group.notify(queue: .main) { completion(keys) }
    }

    //MARK: Свой открытый ключ берётся из Keychain, а не из профиля: там он и рождается,
    // а в профиле лишь опубликован.
    static func own(uid: String) -> String? {
        KeyStore.identityKey(for: uid)?.publicKey.rawRepresentation.base64EncodedString()
    }
}
