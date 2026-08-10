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
    @discardableResult func sendMessage(text: String) -> Bool
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
    // Здесь же расшифровка: ключ приезжает в шапке, а она у презентера под рукой.
    private func rebuildMessages() {
        messages = incoming.map { message in
            message.displayed(sender: sender(for: message.sender.senderId),
                              text: text(of: message))
        }
    }

    //MARK: Нерасшифрованное сообщение — не сбой, который можно замолчать: так
    // выглядит переписка, ключ от которой остался на другом устройстве. Показываем
    // это прямо, а не пустым баблом.
    private func text(of message: Message) -> String {
        guard message.isEncrypted else { return message.body }

        return ConversationCrypto.shared.decrypt(message.body, chat: chat, version: message.keyVersion)
            ?? "🔒 Сообщение не расшифровано"
    }

    private func sender(for id: String) -> Sender {
        Sender(senderId: id, displayName: chat.login(for: id))
    }

    //MARK: Возвращает, приняли ли сообщение к отправке: по этому ответу экран решает,
    // очищать поле ввода или оставить набранное человеку.
    @discardableResult
    func sendMessage(text: String) -> Bool {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }

        //MARK: Без ключа диалога шифровать нечем. Молчать тут нельзя: набранное
        // просто исчезало бы из поля, а в переписке не появлялось — тот самый отказ
        // без реакции, из-за которого экран входа когда-то выглядел сломанным.
        guard !chat.isEncrypted || ConversationCrypto.shared.currentKey(for: chat) != nil else {
            view?.showError("Ключ этого диалога вам ещё не выдан — сообщение не отправлено. Ключ появится, когда создатель чата откроет его.")
            return false
        }

        //MARK: В список локально не добавляем: Firestore отдаёт собственную запись
        // обратно через слушателя сразу, ещё до подтверждения сервером. Ручная
        // вставка продублировала бы сообщение.
        messangerManager.send(text: text, chat: chat)

        return true
    }
}
