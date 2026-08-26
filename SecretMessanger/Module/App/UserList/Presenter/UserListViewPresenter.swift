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

    /// Подпись присутствия: «в сети», «в сети 20 минут назад», «в сети 12 августа».
    ///
    /// Пустая строка — «не знаем», а не «офлайн»: человек, ни разу не заходивший после
    /// появления присутствия, документа не имеет вовсе, и подписать его нечем.
    func presenceText(_ uid: String) -> String
}

class UserListViewPresenter: UserListViewPresenterProtocol {
    
    weak var view: UserListViewProtocol?
    private let userListManager = UserListManager()
    private let presence = PresenceObserver(scope: .everyone)

    //MARK: Хранятся готовые подписи, а не сырые отметки времени. Пульс бьётся у каждого
    // раз в полминуты, и перерисовывать таблицу на каждый удар значило бы дёргать её без
    // конца — вместе с перезаказом аватаров.
    //
    //MARK: Раньше здесь лежало множество тех, кто в сети, и таблица обновлялась, только
    // когда кто-то зажигался или гас. С подписью словами этого мало: «в сети 20 минут
    // назад» устаревает молча, само по себе, без единого события. Сравнивать нужно ровно
    // то, что видно на экране, — и подписи как раз им и являются. Заодно они покрывают
    // и точку: зажечься или погаснуть, не сменив подписи, нельзя.
    //
    // Тот же приём стоит в шапке диалога — см. `MessangerViewPresenter.observePresence`.
    private var presenceTexts: [String: String] = [:]

    //MARK: Считается в тот же момент, что и подписи, и хранится рядом: спрошенное у
    // наблюдателя позже могло бы разойтись с тем, из-за чего таблицу перерисовали.
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

    func presenceText(_ uid: String) -> String {
        presenceTexts[uid] ?? ""
    }
    
    func getAllUsers() {
        userListManager.getAllUsers { [weak self] users in
            guard let self = self else { return }
            self.users = users

            //MARK: Присутствие могло приехать раньше контактов — тогда оно считано по
            // пустому списку, и ни точки, ни подписи не появились бы до первого чужого
            // удара пульса.
            self.refreshPresence()

            self.view?.reloadTable()
        }
    }

    private func observePresence() {
        presence.start { [weak self] _ in
            guard let self else { return }

            let texts = self.currentTexts()

            guard texts != self.presenceTexts else { return }

            self.refreshPresence()
            self.view?.reloadTable()
        }
    }

    private func refreshPresence() {
        presenceTexts = currentTexts()
        onlineNow = Set(users.map { $0.id }.filter { presence.isOnline($0) })
    }

    //MARK: Контакты без документа присутствия в карту не попадают вовсе — у них не
    // «пустая подпись», а её отсутствие, и различать это незачем: ячейка на оба случая
    // прячет строку.
    private func currentTexts() -> [String: String] {
        var texts: [String: String] = [:]

        users.forEach { user in
            guard let state = presence.status(of: user.id) else { return }

            texts[user.id] = state.text()
        }

        return texts
    }
}
