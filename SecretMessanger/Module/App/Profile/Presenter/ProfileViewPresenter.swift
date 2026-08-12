//
//  ProfileViewPresenter.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 30.01.2025.
//

import UIKit

/// Свой профиль. Слушает документ, поэтому правка видна без перезахода.
protocol ProfileViewPresenterProtocol: AnyObject {
    /// `nil` — профиль ещё не пришёл; экран показывает пустую таблицу, а не пустые поля.
    var activeUser: ActiveUser? { get }
    var avatar: UIImage? { get }
}

class ProfileViewPresenter: ProfileViewPresenterProtocol {
    weak var view: ProfileViewProtocol?

    private let profileManager = ProfileManager()

    //MARK: `nil` — профиль ещё не пришёл. Пустой `ActiveUser` тут не годился бы:
    // экран показал бы четыре пустые строки вместо ничего.
    private(set) var activeUser: ActiveUser?
    private(set) var avatar: UIImage?

    required init(view: any ProfileViewProtocol) {
        self.view = view
        getActiveUser()
    }

    deinit {
        profileManager.stopObserving()
    }
    
    func getActiveUser() {
        profileManager.getActiveUser { [weak self] activeUser in
            guard let self = self else { return }

            let versionChanged = self.activeUser?.avatarVersion != activeUser.avatarVersion

            self.activeUser = activeUser
            self.view?.reloadTable()

            //MARK: Профиль слушается, поэтому смена аватара доезжает сюда сама — но
            // только сменой номера версии. Одна и та же версия картинку не
            // перечитывает: она уже в кэше, а поход в базу на каждое чужое изменение
            // профиля бессмыслен.
            guard versionChanged else { return }

            AvatarStore.shared.load(uid: activeUser.id, version: activeUser.avatarVersion) { [weak self] image in
                self?.avatar = image
                self?.view?.reloadAvatar()
            }
        }
    }
}
