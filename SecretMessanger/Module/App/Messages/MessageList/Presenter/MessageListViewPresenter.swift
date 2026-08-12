//
//  MessageListViewPresenter.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 31.01.2025.
//

import Foundation

/// Список «Чаты»: диалоги свежими сверху и аватары собеседников.
protocol MessageListViewPresenterProtocol: AnyObject {
    var conversations: [Conversation] { get }
    func chat(at index: Int) -> Chat

    /// Версия аватара собеседника; ноль — аватара нет или мы его ещё не спросили.
    func avatarVersion(for uid: String) -> Int
}

class MessageListViewPresenter: MessageListViewPresenterProtocol {

    weak var view: MessageListViewProtocol?

    private let messageListManager = MessageListManager()

    private(set) var conversations: [Conversation] = []

    //MARK: Версии аватаров собеседников. В шапке диалога их нет — там кэшируются только
    // логины, — поэтому версии читаются из профилей отдельно.
    private var avatarVersions: [String: Int] = [:]

    //MARK: Кого уже спрашивали. Список чатов перечитывается на каждое сообщение в любом
    // из диалогов, и без этой пометки один и тот же профиль опрашивался бы снова и снова.
    // Сюда попадают и те, у кого аватара нет: их отсутствие — тоже ответ.
    private var askedUids: Set<String> = []

    required init(view: any MessageListViewProtocol) {
        self.view = view

        observeConversations()
    }

    deinit {
        messageListManager.stopObserving()
    }

    private func observeConversations() {
        guard let selfId = FirebaseManager.shared.getUser()?.uid else { return }

        messageListManager.observeConversations(selfId: selfId) { [weak self] conversations in
            guard let self else { return }

            self.conversations = conversations

            DispatchQueue.main.async {
                self.view?.reloadTable()
                self.loadAvatarVersions()
            }
        }
    }

    //MARK: Версии спрашиваются только у новых собеседников — у тех, кого в списке ещё не
    // было. Аватар, сменённый собеседником при открытом списке, догонит при следующем
    // запуске: слушатель на чужие профили ради строки в списке того не стоит. Тот же
    // размен, что в переписке.
    private func loadAvatarVersions() {
        let uids = Set(conversations.compactMap { $0.companionId }).subtracting(askedUids)

        guard !uids.isEmpty else { return }

        askedUids.formUnion(uids)

        AvatarStore.shared.versions(for: Array(uids)) { [weak self] versions in
            guard let self, !versions.isEmpty else { return }

            self.avatarVersions.merge(versions) { _, new in new }
            self.view?.reloadTable()
        }
    }

    func avatarVersion(for uid: String) -> Int {
        avatarVersions[uid] ?? 0
    }

    func chat(at index: Int) -> Chat {
        conversations[index].chat
    }
}
