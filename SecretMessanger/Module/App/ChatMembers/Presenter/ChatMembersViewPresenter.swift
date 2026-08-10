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
    private let crypto = ConversationCrypto.shared
    private var chat: Chat

    //MARK: Открытые ключи участников нужны в момент правки состава: добавленному —
    // запечатать ключ диалога, оставшимся — новый ключ после ротации. Загружаются
    // один раз при открытии экрана, чтобы не бегать в базу из обработчика свайпа.
    private var knownPublicKeys: [String: String] = [:]

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
        loadPublicKeys()
    }

    private func loadPublicKeys() {
        PublicKeyDirectory.keys(for: chat.members) { [weak self] keys in
            guard let self else { return }

            self.knownPublicKeys = keys

            //MARK: Свой ключ берём из Keychain: в профиле он тоже есть, но источник
            // истины здесь, а не там.
            if let mine = PublicKeyDirectory.own(uid: self.chat.selfId) {
                self.knownPublicKeys[self.chat.selfId] = mine
            }
        }
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

        let remaining = chat.members.filter { $0 != member.id }

        //MARK: Логин удалённого из карты не вычищаем: он ничему не мешает (название
        // и подписи собираются по составу, а не по карте) и пригодится, если
        // человека вернут обратно.
        apply(members: remaining, logins: chat.logins, keys: rotatedKeys(for: remaining))
    }

    //MARK: Ротация ключа при удалении. Правила закрывают удалённому доступ к диалогу,
    // но ключ, которым шифровались сообщения, у него на руках навсегда — без нового
    // ключа он остался бы криптографически способен читать всё, что напишут дальше.
    //
    // Старые версии из шапки не убираются: без них переписка стала бы нечитаемой у
    // тех, кто остался. Уже написанное удалённый прочтёт в любом случае — он это
    // видел, когда был в группе.
    private func rotatedKeys(for remaining: [String]) -> [String: Any] {
        guard chat.isEncrypted else { return [:] }

        let version = chat.keyVersion + 1
        let publicKeys = knownPublicKeys.filter { remaining.contains($0.key) }

        guard !publicKeys.isEmpty else { return [:] }

        let entries = crypto.sealed(key: crypto.newKey(),
                                    version: version,
                                    convoId: chat.id,
                                    for: publicKeys)

        guard !entries.isEmpty else { return [:] }

        return ["convoKeys": entries, "keyVersion": version]
    }

    func add(contacts: [ChatUser]) {
        guard canManage, !contacts.isEmpty else { return }

        var members = chat.members
        var logins = chat.logins
        var added: [String: String] = [:]

        contacts.forEach {
            guard !members.contains($0.id) else { return }

            members.append($0.id)
            logins[$0.id] = $0.login

            if !$0.publicKey.isEmpty {
                added[$0.id] = $0.publicKey
                knownPublicKeys[$0.id] = $0.publicKey
            }
        }

        //MARK: Новичку отдаём все версии ключа: правила и так дают ему прочитать всю
        // историю, а без старых ключей он увидел бы вместо неё стену нерасшифрованного.
        let keys = chat.isEncrypted && !added.isEmpty
            ? ["convoKeys": crypto.sealedAllVersions(chat: chat, for: added)]
            : [:]

        apply(members: members, logins: logins, keys: keys)
    }

    private func apply(members: [String], logins: [String: String], keys: [String: Any]) {
        chatMembersManager.update(chat: chat, members: members, logins: logins, keys: keys) { [weak self] err in
            guard let err else { return }

            DispatchQueue.main.async {
                self?.view?.showError(err.localizedDescription)
            }
        }
    }
}
