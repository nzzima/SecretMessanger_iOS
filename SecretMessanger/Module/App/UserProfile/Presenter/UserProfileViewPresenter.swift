//
//  UserProfileViewPresenter.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 21.02.2025.
//

import Foundation

protocol UserProfileViewPresenterProtocol: AnyObject {
    var title: String { get }
    var profile: ProfileInfo? { get }
    var chatUser: ChatUser { get }
}

class UserProfileViewPresenter: UserProfileViewPresenterProtocol {

    weak var view: UserProfileViewProtocol?

    private let userProfileManager = UserProfileManager()
    private let userId: String
    private let fallbackLogin: String

    private(set) var profile: ProfileInfo?

    //MARK: Пока профиль не подгрузился, заголовок берём из списка контактов —
    // экран не должен открываться безымянным.
    var title: String {
        guard let login = profile?.login, !login.isEmpty else { return fallbackLogin }
        return login
    }

    var chatUser: ChatUser {
        ChatUser(id: userId, login: title)
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
                    self.profile = profile
                    self.view?.reloadProfile()
                case .failure(let err):
                    self.view?.showError(err.localizedDescription)
                }
            }
        }
    }
}
