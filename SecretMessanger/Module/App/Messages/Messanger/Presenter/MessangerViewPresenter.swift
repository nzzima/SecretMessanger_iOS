//
//  MessangerViewPresenter.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 04.08.2026.
//

import Foundation

protocol MessangerViewPresenterProtocol: AnyObject {
    var title: String { get }
    var isGroup: Bool { get }
    var selfSender: Sender { get }
    var messages: [Message] { get }
    func sendMessage(text: String)
}

class MessangerViewPresenter: MessangerViewPresenterProtocol {

    weak var view: MessangerViewProtocol?

    private let messangerManager = MessangerManager()
    private let chat: Chat

    private(set) var messages: [Message] = []

    var title: String { chat.title }
    var isGroup: Bool { chat.isGroup }

    var selfSender: Sender {
        Sender(senderId: chat.selfId, displayName: chat.login(for: chat.selfId))
    }

    required init(view: MessangerViewProtocol?, chat: Chat) {
        self.view = view
        self.chat = chat

        observeMessages()
    }

    deinit {
        messangerManager.stopObserving()
    }

    private func observeMessages() {
        messangerManager.ensureConversation(chat: chat) { [weak self] in
            self?.startObserving()
        }
    }

    private func startObserving() {
        messangerManager.observeMessages(convoId: chat.id) { [weak self] messages in
            guard let self else { return }

            self.messages = messages.map { message in
                Message(sender: self.sender(for: message.sender.senderId),
                        messageId: message.messageId,
                        sentDate: message.sentDate,
                        kind: message.kind)
            }

            DispatchQueue.main.async {
                self.view?.reloadCollection()
            }
        }
    }

    //MARK: Отправитель в базе хранится одним лишь id — имя берём из состава чата,
    // он же лежит в шапке диалога. Работает и для группы, а не только для пары.
    private func sender(for id: String) -> Sender {
        Sender(senderId: id, displayName: chat.login(for: id))
    }

    func sendMessage(text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        //MARK: В список локально не добавляем: Firestore отдаёт собственную запись
        // обратно через слушателя сразу, ещё до подтверждения сервером. Ручная
        // вставка продублировала бы сообщение.
        messangerManager.send(text: text, chat: chat)
    }
}
