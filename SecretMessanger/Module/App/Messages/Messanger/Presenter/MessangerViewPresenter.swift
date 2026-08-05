//
//  MessangerViewPresenter.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 04.08.2026.
//

import Foundation

protocol MessangerViewPresenterProtocol: AnyObject {
    var title: String { get }
    var selfSender: Sender { get }
    var messages: [Message] { get }
    func sendMessage(text: String)
}

class MessangerViewPresenter: MessangerViewPresenterProtocol {

    weak var view: MessangerViewProtocol?

    private let messangerManager = MessangerManager()
    private let convoId: String
    private let otherSender: Sender

    private(set) var selfSender: Sender
    private(set) var messages: [Message] = []

    var title: String {
        otherSender.displayName
    }

    required init(view: MessangerViewProtocol?, chatUser: ChatUser) {
        self.view = view

        let selfId = FirebaseManager.shared.getUser()?.uid ?? ""

        self.selfSender = Sender(senderId: selfId,
                                 displayName: UserDefaults.standard.string(forKey: "selfName") ?? "")
        self.otherSender = Sender(senderId: chatUser.id, displayName: chatUser.login)
        self.convoId = MessangerManager.conversationId(selfId, chatUser.id)

        observeMessages()
    }

    deinit {
        messangerManager.stopObserving()
    }

    private func observeMessages() {
        messangerManager.observeMessages(convoId: convoId) { [weak self] messages in
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

    //MARK: В диалоге на двоих отправитель всегда один из двух, поэтому имя
    // восстанавливается по id без похода в базу.
    private func sender(for id: String) -> Sender {
        id == selfSender.senderId ? selfSender : otherSender
    }

    func sendMessage(text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        //MARK: В список локально не добавляем: Firestore отдаёт собственную запись
        // обратно через слушателя сразу, ещё до подтверждения сервером. Ручная
        // вставка продублировала бы сообщение.
        messangerManager.send(text: text,
                              convoId: convoId,
                              from: selfSender,
                              to: otherSender)
    }
}
