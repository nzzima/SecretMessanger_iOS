//
//  MessangerViewPresenter.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 04.08.2026.
//

import Foundation

protocol MessangerViewPresenterProtocol: AnyObject {
    var chat: Chat { get }
    var title: String { get }
    var isGroup: Bool { get }
    var selfSender: Sender { get }
    var messages: [Message] { get }
    func sendMessage(text: String)
}

class MessangerViewPresenter: MessangerViewPresenterProtocol {

    weak var view: MessangerViewProtocol?

    private let messangerManager = MessangerManager()

    //MARK: Состав чата больше не константа: создатель может добавить или убрать
    // участника, пока экран открыт. Отсюда `var` и слушатель на шапку.
    private(set) var chat: Chat

    private var incoming: [Message] = []
    private(set) var messages: [Message] = []

    var title: String { chat.title }
    var isGroup: Bool { chat.isGroup }

    var selfSender: Sender {
        Sender(senderId: chat.selfId, displayName: chat.login(for: chat.selfId))
    }

    required init(view: MessangerViewProtocol?, chat: Chat) {
        self.view = view
        self.chat = chat

        start()
    }

    deinit {
        messangerManager.stopObserving()
    }

    private func start() {
        messangerManager.ensureConversation(chat: chat) { [weak self] in
            self?.observeConversation()
            self?.observeMessages()
        }
    }

    private func observeConversation() {
        messangerManager.observeConversation(chat: chat) { [weak self] chat in
            guard let self else { return }

            self.chat = chat

            //MARK: Имена берутся из состава, поэтому подписи под сообщениями надо
            // пересобрать: иначе добавленный участник остался бы безымянным до
            // перезахода в чат.
            self.rebuildMessages()

            DispatchQueue.main.async {
                self.view?.reloadTitle()
                self.view?.reloadCollection()
            }
        }
    }

    private func observeMessages() {
        messangerManager.observeMessages(convoId: chat.id) { [weak self] messages in
            guard let self else { return }

            self.incoming = messages
            self.rebuildMessages()

            DispatchQueue.main.async {
                self.view?.reloadCollection()
            }
        }
    }

    //MARK: Отправитель в базе хранится одним лишь id — имя подставляется из состава
    // чата, он же лежит в шапке диалога. Работает и для группы, а не только для пары.
    private func rebuildMessages() {
        messages = incoming.map { message in
            Message(sender: sender(for: message.sender.senderId),
                    messageId: message.messageId,
                    sentDate: message.sentDate,
                    kind: message.kind)
        }
    }

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
