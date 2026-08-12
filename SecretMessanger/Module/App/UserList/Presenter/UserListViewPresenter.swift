//
//  UserListViewPresenter.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 30.01.2025.
//

import Foundation

/// Список контактов — все зарегистрированные, кроме себя.
protocol UserListViewPresenterProtocol: AnyObject {
    var users: [ChatUser] { get set }
}

class UserListViewPresenter: UserListViewPresenterProtocol {
    
    weak var view: UserListViewProtocol?
    private let userListManager = UserListManager()
    
    var users: [ChatUser] = []
    
    required init(view: any UserListViewProtocol) {
        self.view = view
        getAllUsers()
    }

    deinit {
        userListManager.stopObserving()
    }
    
    func getAllUsers() {
        userListManager.getAllUsers { [weak self] users in
            guard let self = self else { return }
            self.users = users
            self.view?.reloadTable()
        }
    }
}
