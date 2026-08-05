//
//  MessageListViewPresenter.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 31.01.2025.
//

import Foundation

protocol MessageListViewPresenterProtocol: AnyObject {
    var conversations: [Conversation] { get }
    func chatUser(at index: Int) -> ChatUser
}

class MessageListViewPresenter: MessageListViewPresenterProtocol {

    weak var view: MessageListViewProtocol?

    private let messageListManager = MessageListManager()

    private(set) var conversations: [Conversation] = []

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
            }
        }
    }

    func chatUser(at index: Int) -> ChatUser {
        let conversation = conversations[index]

        return ChatUser(id: conversation.otherId, login: conversation.otherLogin)
    }
}
