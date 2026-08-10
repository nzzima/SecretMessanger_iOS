//
//  ChatMembersViewPresenter.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 10.08.2026.
//

import Foundation

struct ChatMember {
    let id: String
    let login: String
    let isOwner: Bool
    let isSelf: Bool
}

protocol ChatMembersViewPresenterProtocol: AnyObject {
    var members: [ChatMember] { get }
    var canManage: Bool { get }
    var excludedIds: Set<String> { get }
    func canRemove(at index: Int) -> Bool
    func remove(at index: Int)
    func add(contacts: [ChatUser])
}

class ChatMembersViewPresenter: ChatMembersViewPresenterProtocol {

    weak var view: ChatMembersViewProtocol?

    private let chatMembersManager = ChatMembersManager()
    private var chat: Chat

    //MARK: Ниже трёх участников группу опускать нельзя. Дело не в вкусе: у
    // переписки на двоих id детерминированный — пара uid по алфавиту, — и группа с
    // случайным id, ужавшись до двоих, стала бы вторым чатом тех же людей рядом с
    // их обычным. Двое остаются вдвоём в своей переписке, а не в остатке группы.
    private let minimumMembers = 3

    var canManage: Bool { chat.isOwner }

    var members: [ChatMember] {
        chat.members.map {
            ChatMember(id: $0,
                       login: chat.login(for: $0),
                       isOwner: $0 == chat.owner,
                       isSelf: $0 == chat.selfId)
        }
    }

    var excludedIds: Set<String> { Set(chat.members) }

    required init(view: ChatMembersViewProtocol?, chat: Chat) {
        self.view = view
        self.chat = chat

        observe()
    }

    deinit {
        chatMembersManager.stopObserving()
    }

    private func observe() {
        chatMembersManager.observe(chat: chat) { [weak self] chat in
            guard let self else { return }

            self.chat = chat

            DispatchQueue.main.async {
                self.view?.reloadTable()
            }
        }
    }

    //MARK: Себя не удаляем: правила запрещают создателю вычеркнуть себя, а выхода
    // из группы для остальных пока нет — он тянет за собой вопрос, кому достаётся
    // группа, если уходит создатель.
    func canRemove(at index: Int) -> Bool {
        let member = members[index]

        return canManage && !member.isSelf && chat.members.count > minimumMembers
    }

    func remove(at index: Int) {
        let member = members[index]

        guard canManage, !member.isSelf else { return }

        guard chat.members.count > minimumMembers else {
            view?.showError("В группе должно остаться хотя бы \(minimumMembers) участника. Переписка на двоих — это отдельный чат из «Контактов».")
            return
        }

        //MARK: Логин удалённого из карты не вычищаем: он ничему не мешает (название
        // и подписи собираются по составу, а не по карте) и пригодится, если
        // человека вернут обратно.
        apply(members: chat.members.filter { $0 != member.id }, logins: chat.logins)
    }

    func add(contacts: [ChatUser]) {
        guard canManage, !contacts.isEmpty else { return }

        var members = chat.members
        var logins = chat.logins

        contacts.forEach {
            guard !members.contains($0.id) else { return }

            members.append($0.id)
            logins[$0.id] = $0.login
        }

        apply(members: members, logins: logins)
    }

    private func apply(members: [String], logins: [String: String]) {
        chatMembersManager.update(chat: chat, members: members, logins: logins) { [weak self] err in
            guard let err else { return }

            DispatchQueue.main.async {
                self?.view?.showError(err.localizedDescription)
            }
        }
    }
}
