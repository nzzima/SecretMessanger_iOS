//
//  UserProfileViewPresenter.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 21.02.2025.
//

import UIKit

/// Профиль собеседника и кнопка «написать».
protocol UserProfileViewPresenterProtocol: AnyObject {
    /// Пока профиль не подгрузился — имя из списка контактов: экран не должен
    /// открываться безымянным.
    var title: String { get }
    var profile: ProfileInfo? { get }
    var avatar: UIImage? { get }

    /// «в сети», «в сети вчера в 21:14». Пустая, пока присутствие неизвестно.
    var status: String { get }

    /// Диалог с этим человеком. Id соберётся из пары uid, поэтому кнопка открывает
    /// существующую переписку, а не заводит вторую.
    var chat: Chat? { get }
}

class UserProfileViewPresenter: UserProfileViewPresenterProtocol {

    weak var view: UserProfileViewProtocol?

    private let userProfileManager = UserProfileManager()

    //MARK: Контакт хранится целиком, а не разобранным на id и логин. Раньше от него
    // оставляли эти два поля, а `chat` собирал собеседника заново — `ChatUser(id:login:)`,
    // у которого `publicKey` пустой по умолчанию. Диалог из-за этого заводился с ключом,
    // запечатанным только для себя, и собеседник видел «🔒 Сообщение не расшифровано» до
    // тех пор, пока создатель не откроет чат второй раз и не сработает дозапечатывание.
    // Открытый ключ всё это время лежал в переданном `ChatUser` — его выбрасывали на
    // ровном месте.
    private let contact: ChatUser

    private var userId: String { contact.id }
    private var fallbackLogin: String { contact.login }

    private(set) var profile: ProfileInfo?
    private(set) var avatar: UIImage?
    private(set) var status = ""

    private lazy var presence = PresenceObserver(scope: .one(userId))

    //MARK: Пока профиль не подгрузился, заголовок берём из списка контактов —
    // экран не должен открываться безымянным.
    var title: String {
        guard let login = profile?.login, !login.isEmpty else { return fallbackLogin }
        return login
    }

    //MARK: Диалог на двоих: id соберётся из пары uid, поэтому кнопка «написать»
    // открывает существующую переписку, а не заводит вторую.
    var chat: Chat? {
        guard let selfId = FirebaseManager.shared.getUser()?.uid else { return nil }

        //MARK: Логин подставляем свежий — профиль подгружается после списка контактов и
        // мог принести переименование. Всё остальное, и прежде всего `publicKey`, едет
        // как пришло: именно он решает, сможет ли собеседник прочитать первое сообщение.
        var companion = contact
        companion.login = title

        return Chat(selfId: selfId,
                    selfLogin: SelfName.current,
                    contacts: [companion])
    }

    required init(view: any UserProfileViewProtocol, chatUser: ChatUser) {
        self.view = view
        self.contact = chatUser

        observeProfile()
        observePresence()
    }

    deinit {
        userProfileManager.stopObserving()
        presence.stop()
    }

    private func observePresence() {
        presence.start { [weak self] _ in
            guard let self else { return }

            //MARK: Пустая строка — «не знаем»: у человека, не заходившего после
            // появления присутствия, документа нет вовсе, и строка в профиле просто
            // не показывается.
            let updated = self.presence.status(of: self.userId)?.text() ?? ""

            guard updated != self.status else { return }

            self.status = updated
            self.view?.reloadProfile()
        }
    }

    private func observeProfile() {
        userProfileManager.observeProfile(userId: userId) { [weak self] result in
            guard let self else { return }

            DispatchQueue.main.async {
                switch result {
                case .success(let profile):
                    let versionChanged = self.profile?.avatarVersion != profile.avatarVersion

                    self.profile = profile
                    self.view?.reloadProfile()

                    //MARK: Профиль слушается — собеседник может сменить аватар прямо
                    // при открытом экране. Перечитываем только на смену версии: тот же
                    // снапшот приходит и на правку заметки, а картинка от этого не
                    // меняется.
                    guard versionChanged else { return }

                    AvatarStore.shared.load(uid: self.userId, version: profile.avatarVersion) { [weak self] image in
                        self?.avatar = image
                        self?.view?.reloadAvatar()
                    }
                case .failure(let err):
                    self.view?.showError(err.localizedDescription)
                }
            }
        }
    }
}
