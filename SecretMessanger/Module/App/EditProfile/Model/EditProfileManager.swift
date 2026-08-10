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
    private let registry = LoginRegistry()

    //MARK: Здесь висели два слушателя на всю коллекцию `users` — по одному на каждое
    // поле одного и того же документа, и ни один не отцеплялся. Форме редактирования
    // живые обновления не нужны: свой документ читается один раз, при открытии.
    func getActiveUser(completion: @escaping (ActiveUser) -> Void) {
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

                completion(ActiveUser(id: uid, userInfo: userData))
            }
    }

    //MARK: Порядок шагов здесь — вся суть переименования, и он ровно обратный
    // интуитивному. Сначала занимаем новое имя, потом переписываем профиль, и только
    // последним отпускаем старое.
    //
    // Иначе: отпустив старое первым, мы бы освободили своё имя ещё до того, как
    // убедились, что новое достанется нам, — и на занятом новом остались бы вовсе без
    // логина, а старое к тому моменту мог забрать кто угодно. Профиль же нельзя
    // переписать раньше захвата: правила требуют, чтобы логин в нём был уже занят
    // этим пользователем.
    //
    // Обрыв посередине не ломает ничего: у нас окажутся заняты оба имени, а повторная
    // попытка увидит новое уже своим и просто доведёт дело до конца.
    func save(login: String, name: String, someInfo: String, currentLogin: String,
              completion: @escaping (Error?) -> Void) {
        guard let uid = FirebaseManager.shared.getUser()?.uid else { return }

        guard LoginRegistry.key(for: login) != LoginRegistry.key(for: currentLogin) else {
            //MARK: Логин не менялся — либо изменился только регистр, а он в ключ
            // реестра не входит. Занимать нечего и отпускать нечего: та же запись
            // реестра, что и была, продолжает держать имя за нами. Пойди мы общим
            // путём, последним шагом мы бы удалили собственный захват.
            write(uid: uid, login: login, name: name, someInfo: someInfo, completion: completion)
            return
        }

        registry.check(login: login, uid: uid) { [weak self] result in
            guard let self else { return }

            switch result {
            case .failure(let err):
                completion(err)
            case .success(.taken):
                completion(LoginRegistryError.taken)
            case .success(.mine):
                //MARK: Имя уже наше — так выглядит повторная попытка после обрыва.
                self.writeAndRelease(uid: uid, login: login, name: name,
                                     someInfo: someInfo, oldLogin: currentLogin,
                                     completion: completion)
            case .success(.free):
                self.registry.claim(login: login, uid: uid) { err in
                    guard err == nil else {
                        completion(err)
                        return
                    }

                    self.writeAndRelease(uid: uid, login: login, name: name,
                                         someInfo: someInfo, oldLogin: currentLogin,
                                         completion: completion)
                }
            }
        }
    }

    private func writeAndRelease(uid: String, login: String, name: String, someInfo: String,
                                 oldLogin: String, completion: @escaping (Error?) -> Void) {
        write(uid: uid, login: login, name: name, someInfo: someInfo) { [weak self] err in
            guard err == nil else {
                completion(err)
                return
            }

            self?.registry.release(login: oldLogin) { err in
                //MARK: Старое имя не отпустилось — переименование при этом состоялось,
                // и держать человека на экране незачем. Хуже всего тут молчание: имя
                // осталось бы занятым за нами навсегда и незаметно.
                if let err {
                    print("Старый логин не освободился: \(err.localizedDescription)")
                }

                completion(nil)
            }
        }
    }

    private func write(uid: String, login: String, name: String, someInfo: String,
                       completion: @escaping (Error?) -> Void) {
        ref
            .collection(.users)
            .document(uid)
            .setData([
                "login": login,
                "name": name,
                "someInfo": someInfo
            ], merge: true) { err in
                completion(err)
            }
    }
}
