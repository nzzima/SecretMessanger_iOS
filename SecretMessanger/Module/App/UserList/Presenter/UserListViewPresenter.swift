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

    /// В сети ли контакт прямо сейчас — для точки в его строке.
    func isOnline(_ uid: String) -> Bool
}

class UserListViewPresenter: UserListViewPresenterProtocol {
    
    weak var view: UserListViewProtocol?
    private let userListManager = UserListManager()
    private let presence = PresenceObserver(scope: .everyone)

    //MARK: Хранится именно множество тех, кто в сети, а не сырые отметки времени. Пульс
    // бьётся у каждого раз в полминуты, и перерисовывать таблицу на каждый удар значило
    // бы дёргать её без конца — вместе с перезаказом аватаров. Список меняется только
    // когда кто-то действительно зажёгся или погас, а это событие редкое.
    private var onlineNow: Set<String> = []

    var users: [ChatUser] = []
    
    required init(view: any UserListViewProtocol) {
        self.view = view
        getAllUsers()
        observePresence()
    }

    deinit {
        userListManager.stopObserving()
        presence.stop()
    }

    func isOnline(_ uid: String) -> Bool {
        onlineNow.contains(uid)
    }
    
    func getAllUsers() {
        userListManager.getAllUsers { [weak self] users in
            guard let self = self else { return }
            self.users = users

            //MARK: Присутствие могло приехать раньше контактов — тогда множество считано
            // по пустому списку и точки не зажглись бы до первого чужого удара.
            self.onlineNow = self.currentlyOnline()

            self.view?.reloadTable()
        }
    }

    private func observePresence() {
        presence.start { [weak self] _ in
            guard let self else { return }

            let online = self.currentlyOnline()

            guard online != self.onlineNow else { return }

            self.onlineNow = online
            self.view?.reloadTable()
        }
    }

    private func currentlyOnline() -> Set<String> {
        Set(users.map { $0.id }.filter { presence.isOnline($0) })
    }
}
