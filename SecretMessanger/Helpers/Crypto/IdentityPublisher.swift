//
//  IdentityPublisher.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 10.08.2026.
//

import Foundation
import FirebaseFirestore

//MARK: Открытый ключ публикуется не только при входе, но и при каждом запуске
// приложения. Иначе получилась бы та же дыра, что с реестром логинов: `ensureProfile`
// срабатывает лишь на явном входе, а сессия Firebase живёт месяцами — человек с
// давней сессией так и остался бы без опубликованного ключа, и запечатать для него
// ключ диалога никто бы не смог.
enum IdentityPublisher {

    static func publishIfNeeded() {
        guard let uid = FirebaseManager.shared.getUser()?.uid,
              let publicKey = PublicKeyDirectory.own(uid: uid) else { return }

        let document = Firestore.firestore().collection(.users).document(uid)

        document.getDocument { snap, err in
            guard err == nil, let snap, snap.exists else { return }

            //MARK: Профиля может не быть — тогда молчим: правила требуют, чтобы в
            // записи был занятый логин, а заводит его `ensureProfile` при входе.
            // Дописывать сюда ещё и логин значило бы продублировать всю ту логику.
            guard (snap.data()?["publicKey"] as? String ?? "") != publicKey else { return }

            document.setData(["publicKey": publicKey], merge: true) { err in
                if let err {
                    print("Открытый ключ не опубликован: \(err.localizedDescription)")
                }
            }
        }
    }
}
