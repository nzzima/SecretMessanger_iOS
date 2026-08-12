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

/// Экран «Участники»: кто в группе и что с этим можно сделать.
protocol ChatMembersViewPresenterProtocol: AnyObject {
    var members: [ChatMember] { get }

    /// Правит состав только создатель — у остальных экран только для чтения.
    var canManage: Bool { get }

    /// Создателю выход закрыт: группа без хозяина осталась бы с замороженным составом.
    var canLeave: Bool { get }

    /// Кого не показывать в списке добавления — они уже в группе.
    var excludedIds: Set<String> { get }
    func canRemove(at index: Int) -> Bool

    /// Удаляет участника и **ротирует ключ**: без этого удалённый остался бы
    /// криптографически способен читать всё, что напишут дальше.
    func remove(at index: Int)

    /// Добавляет людей и выдаёт им все версии ключа — иначе история выглядела бы стеной
    /// нерасшифрованного, а секрета бы не прибавилось.
    func add(contacts: [ChatUser])

    /// Выход по своей воле. Ключи не ротируются: ушедший и так прочитал всё, что видел.
    func leave()
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

    var canManage: Bool { chat.isOwner }

    //MARK: Создателю выход закрыт — правило требует, чтобы он остался: иначе группа
    // осталась бы без единственного, кто может править состав, а передачи прав пока
    // нет. Для него это ограничение, а не забытая кнопка, поэтому экран говорит об
    // этом прямо.
    var canLeave: Bool { !chat.isOwner }

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

    //MARK: Себя из списка не удаляем — для этого есть выход, у него своё правило.
    func canRemove(at index: Int) -> Bool {
        let member = members[index]

        return canManage && !member.isSelf
    }

    func remove(at index: Int) {
        let member = members[index]

        guard canManage, !member.isSelf else { return }

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

    func leave() {
        guard canLeave else { return }

        chatMembersManager.leave(chat: chat) { [weak self] err in
            DispatchQueue.main.async {
                guard let err else {
                    self?.view?.left()
                    return
                }

                self?.view?.showError(err.localizedDescription)
            }
        }
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
