//
//  NewChatViewPresenter.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 07.08.2026.
//

import Foundation

//MARK: Экран один на два случая, потому что действие одно: отметить людей в списке
// контактов. Дальше расходится только результат — новый чат или добавление в
// существующую группу, — и решает это тот, кто экран открыл.
enum NewChatMode {
    case create
    case addMembers(excluded: Set<String>, onAdd: ([ChatUser]) -> Void)
}

protocol NewChatViewPresenterProtocol: AnyObject {
    var users: [ChatUser] { get }
    var selectedCount: Int { get }
    var isAddingMembers: Bool { get }
    func isSelected(at index: Int) -> Bool
    func toggleSelection(at index: Int)
    func makeChat() -> Chat?
    func addSelected()
}

class NewChatViewPresenter: NewChatViewPresenterProtocol {

    weak var view: NewChatViewProtocol?

    private let userListManager = UserListManager()
    private let mode: NewChatMode
    private var selectedIds: Set<String> = []

    private(set) var users: [ChatUser] = []

    var selectedCount: Int { selectedIds.count }

    var isAddingMembers: Bool {
        if case .addMembers = mode { return true }
        return false
    }

    private var excluded: Set<String> {
        if case .addMembers(let excluded, _) = mode { return excluded }
        return []
    }

    required init(view: any NewChatViewProtocol, mode: NewChatMode = .create) {
        self.view = view
        self.mode = mode

        getAllUsers()
    }

    deinit {
        userListManager.stopObserving()
    }

    private func getAllUsers() {
        userListManager.getAllUsers { [weak self] users in
            guard let self else { return }

            //MARK: Тех, кто уже в группе, в списке нет — иначе их можно было бы
            // «добавить» повторно и получить пустое действие вместо ошибки.
            self.users = users.filter { !self.excluded.contains($0.id) }

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

    private var selectedContacts: [ChatUser] {
        users.filter { selectedIds.contains($0.id) }
    }

    //MARK: Один выбранный контакт — обычный диалог, несколько — группа. Отдельной
    // кнопки «создать группу» нет: разница только в числе участников, и `Chat`
    // выводит и название, и признак группы из состава.
    func makeChat() -> Chat? {
        guard let selfId = FirebaseManager.shared.getUser()?.uid, !selectedIds.isEmpty else { return nil }

        let selfLogin = SelfName.current

        return Chat(selfId: selfId, selfLogin: selfLogin, contacts: selectedContacts)
    }

    func addSelected() {
        guard case .addMembers(_, let onAdd) = mode, !selectedIds.isEmpty else { return }

        onAdd(selectedContacts)
    }
}
