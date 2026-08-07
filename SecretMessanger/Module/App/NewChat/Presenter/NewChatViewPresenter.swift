//
//  NewChatViewPresenter.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 07.08.2026.
//

import Foundation

protocol NewChatViewPresenterProtocol: AnyObject {
    var users: [ChatUser] { get }
    var selectedCount: Int { get }
    func isSelected(at index: Int) -> Bool
    func toggleSelection(at index: Int)
    func makeChat() -> Chat?
}

class NewChatViewPresenter: NewChatViewPresenterProtocol {

    weak var view: NewChatViewProtocol?

    private let userListManager = UserListManager()
    private var selectedIds: Set<String> = []

    private(set) var users: [ChatUser] = []

    var selectedCount: Int { selectedIds.count }

    required init(view: any NewChatViewProtocol) {
        self.view = view

        getAllUsers()
    }

    deinit {
        userListManager.stopObserving()
    }

    private func getAllUsers() {
        userListManager.getAllUsers { [weak self] users in
            guard let self else { return }

            self.users = users

            DispatchQueue.main.async {
                self.view?.reloadTable()
            }
        }
    }

    func isSelected(at index: Int) -> Bool {
        selectedIds.contains(users[index].id)
    }

    func toggleSelection(at index: Int) {
        let id = users[index].id

        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }

        view?.reloadTable()
    }

    //MARK: Один выбранный контакт — обычный диалог, несколько — группа. Отдельной
    // кнопки «создать группу» нет: разница только в числе участников, и `Chat`
    // выводит и название, и признак группы из состава.
    func makeChat() -> Chat? {
        guard let selfId = FirebaseManager.shared.getUser()?.uid, !selectedIds.isEmpty else { return nil }

        let selfLogin = UserDefaults.standard.string(forKey: "selfName") ?? ""
        let contacts = users.filter { selectedIds.contains($0.id) }

        return Chat(selfId: selfId, selfLogin: selfLogin, contacts: contacts)
    }
}
