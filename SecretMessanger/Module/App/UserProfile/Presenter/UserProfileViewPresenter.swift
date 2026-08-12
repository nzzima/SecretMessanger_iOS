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

    /// Диалог с этим человеком. Id соберётся из пары uid, поэтому кнопка открывает
    /// существующую переписку, а не заводит вторую.
    var chat: Chat? { get }
}

class UserProfileViewPresenter: UserProfileViewPresenterProtocol {

    weak var view: UserProfileViewProtocol?

    private let userProfileManager = UserProfileManager()
    private let userId: String
    private let fallbackLogin: String

    private(set) var profile: ProfileInfo?
    private(set) var avatar: UIImage?

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

        let selfLogin = SelfName.current

        return Chat(selfId: selfId,
                    selfLogin: selfLogin,
                    contacts: [ChatUser(id: userId, login: title)])
    }

    required init(view: any UserProfileViewProtocol, chatUser: ChatUser) {
        self.view = view
        self.userId = chatUser.id
        self.fallbackLogin = chatUser.login

        observeProfile()
    }

    deinit {
        userProfileManager.stopObserving()
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
