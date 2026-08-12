//
//  ProfileViewPresenter.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 30.01.2025.
//

import Foundation

protocol ProfileViewPresenterProtocol: AnyObject {
    var activeUser: ActiveUser? { get }
}

class ProfileViewPresenter: ProfileViewPresenterProtocol {
    weak var view: ProfileViewProtocol?

    private let profileManager = ProfileManager()

    //MARK: `nil` — профиль ещё не пришёл. Пустой `ActiveUser` тут не годился бы:
    // экран показал бы четыре пустые строки вместо ничего.
    private(set) var activeUser: ActiveUser?

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

            self.activeUser = activeUser
            self.view?.reloadTable()
        }
    }
}
