//
//  EditProfileManager.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 27.02.2025.
//

import Foundation
import Firebase
import FirebaseFirestore

/// Правка своего профиля: поля, логин с переносом в реестре и маркер аватара.
class EditProfileManager {

    private let ref = Firestore.firestore()
    private let registry = LoginRegistry()

    //MARK: Здесь висели два слушателя на всю коллекцию `users` — по одному на каждое
    // поле одного и того же документа, и ни один не отцеплялся. Форме редактирования
    // живые обновления не нужны: свой документ читается один раз, при открытии.
    /// Читает свой профиль один раз, чтобы заполнить форму.
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
    /// Сохраняет профиль, при необходимости перенося захват логина в реестре.
    ///
    /// - Parameter currentLogin: имя до правки. По нему видно, менялся ли логин и надо
    ///   ли рассылать его по шапкам диалогов.
    /// - Note: порядок шагов и его последствия — в пояснении выше.
    func save(login: String, name: String, someInfo: String, currentLogin: String,
              completion: @escaping (Error?) -> Void) {
        guard let uid = FirebaseManager.shared.getUser()?.uid else { return }

        //MARK: Логин в шапках диалогов — кэш, и после переименования его надо
        // разослать. Считаем это здесь, до всех веток: дальше `currentLogin` уже не
        // с чем сравнивать, а изменившийся только регистром логин («red» → «Red»)
        // собеседники тоже должны увидеть новым.
        let renamed = login != currentLogin

        //MARK: Своё имя рассылается по диалогам после успеха любой из веток ниже,
        // поэтому дальше идёт эта обёртка, а не сам `completion`.
        let finish: (Error?) -> Void = { [weak self] err in
            if err == nil, renamed {
                self?.rename(uid: uid, to: login)
            }

            completion(err)
        }

        guard LoginRegistry.key(for: login) != LoginRegistry.key(for: currentLogin) else {
            //MARK: Логин не менялся — либо изменился только регистр, а он в ключ
            // реестра не входит. Занимать нечего и отпускать нечего: та же запись
            // реестра, что и была, продолжает держать имя за нами. Пойди мы общим
            // путём, последним шагом мы бы удалили собственный захват.
            write(uid: uid, login: login, name: name, someInfo: someInfo, completion: finish)
            return
        }

        registry.check(login: login, uid: uid) { [weak self] result in
            guard let self else { return }

            switch result {
            case .failure(let err):
                finish(err)
            case .success(.taken):
                finish(LoginRegistryError.taken)
            case .success(.mine):
                //MARK: Имя уже наше — так выглядит повторная попытка после обрыва.
                self.writeAndRelease(uid: uid, login: login, name: name,
                                     someInfo: someInfo, oldLogin: currentLogin,
                                     completion: finish)
            case .success(.free):
                self.registry.claim(login: login, uid: uid) { err in
                    guard err == nil else {
                        finish(err)
                        return
                    }

                    self.writeAndRelease(uid: uid, login: login, name: name,
                                         someInfo: someInfo, oldLogin: currentLogin,
                                         completion: finish)
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

    //MARK: Маркер аватара в профиле. Пишется он здесь, а не в `AvatarStore`, чтобы все
    // записи в `users/{uid}` остались в одном месте — их стережёт правило `ownsLogin()`,
    // и разбросанные по коду они однажды разошлись бы с ним.
    //
    // Слияние обязательно: правило смотрит на документ целиком, каким он станет после
    // записи, и логин в нём должен остаться на месте.
    func saveAvatarVersion(_ version: Int, completion: @escaping (Error?) -> Void) {
        guard let uid = FirebaseManager.shared.getUser()?.uid else { return }

        ref
            .collection(.users)
            .document(uid)
            .setData(["avatarVersion": version], merge: true) { err in
                completion(err)
            }
    }

    //MARK: Разовый проход по своим диалогам после переименования. Карта `logins` в
    // шапке — кэш имён, и своё имя туда пишется при открытии диалога и при отправке:
    // без этого прохода переименовавшийся оставался бы под старым именем во всех
    // чатах, куда он с тех пор не заходил, — и узнать об этом мог бы только от
    // собеседника.
    //
    // Правила такую запись пропускают как обычную: состав, создатель и ключи не
    // тронуты, а участник шапку писать вправе — ровно то же самое делает отправка
    // сообщения.
    private func rename(uid: String, to login: String) {
        ref
            .collection(.conversation)
            .whereField(.users, arrayContains: uid)
            .getDocuments { [weak self] snap, err in
                guard let self, let documents = snap?.documents, !documents.isEmpty else {
                    if let err {
                        print("Диалоги для переименования не прочитались: \(err.localizedDescription)")
                    }

                    return
                }

                //MARK: Батчем, а не по одной записи: диалогов может быть много, и
                // растягивать переименование на десятки отдельных запросов незачем.
                let batch = self.ref.batch()

                documents.forEach {
                    batch.updateData(["logins.\(uid)": login], forDocument: $0.reference)
                }

                batch.commit { err in
                    //MARK: Неудача здесь не отменяет переименования — оно уже
                    // состоялось в профиле и в реестре. Имя в этих диалогах просто
                    // догонит по-старому, при следующем открытии или отправке.
                    if let err {
                        print("Имя в диалогах не обновилось: \(err.localizedDescription)")
                    }
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
