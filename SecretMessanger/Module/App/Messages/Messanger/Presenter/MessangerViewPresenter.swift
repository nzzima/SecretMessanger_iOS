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
    var isRecording: Bool { get }
    var recordingTime: TimeInterval { get }
    @discardableResult func sendMessage(text: String) -> Bool
    func startRecording()
    func finishRecording()
    func cancelRecording()
    func playVoice(messageId: String, play: @escaping (URL) -> Void)
}

class MessangerViewPresenter: MessangerViewPresenterProtocol {

    weak var view: MessangerViewProtocol?

    private let messangerManager = MessangerManager()
    private let recorder = VoiceRecorder()

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

    var isRecording: Bool { recorder.isRecording }
    var recordingTime: TimeInterval { recorder.currentTime }

    required init(view: MessangerViewProtocol?, chat: Chat) {
        self.view = view
        self.chat = chat

        //MARK: Потолок по длительности срабатывает сам, без участия экрана, поэтому
        // об окончании записи надо сообщить — иначе интерфейс остался бы в режиме
        // записи, которой уже нет.
        recorder.onAutoStop = { [weak self] url, duration in
            DispatchQueue.main.async {
                self?.view?.recordingStopped()
                self?.upload(url: url, duration: duration)
            }
        }

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

    // MARK: - Голосовые

    func startRecording() {
        //MARK: Без ключа шифровать запись нечем — говорим об этом до того, как
        // человек наговорит две минуты впустую.
        guard !chat.isEncrypted || ConversationCrypto.shared.currentKey(for: chat) != nil else {
            view?.showError(ConversationCryptoError.noKey.localizedDescription)
            return
        }

        VoicePlayer.shared.stop()

        recorder.start { [weak self] err in
            guard let err else {
                self?.view?.recordingStarted()
                return
            }

            self?.view?.showError(err.localizedDescription)
        }
    }

    func finishRecording() {
        view?.recordingStopped()

        //MARK: `nil` здесь — запись короче секунды, то есть промах по кнопке. Ругаться
        // на это незачем, отправлять тоже.
        guard let recorded = recorder.stop() else { return }

        upload(url: recorded.url, duration: recorded.duration)
    }

    func cancelRecording() {
        recorder.cancel()
        view?.recordingStopped()
    }

    private func upload(url: URL, duration: TimeInterval) {
        messangerManager.sendVoice(url: url, duration: duration, chat: chat) { [weak self] err in
            //MARK: Файл убираем в любом случае: отправился он или нет, во временной
            // папке ему делать нечего — звук уже либо в базе, либо потерян.
            try? FileManager.default.removeItem(at: url)

            guard let err else { return }

            DispatchQueue.main.async {
                self?.view?.showError(err.localizedDescription)
            }
        }
    }

    func playVoice(messageId: String, play: @escaping (URL) -> Void) {
        messangerManager.loadVoice(messageId: messageId, chat: chat) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let url):
                    play(url)
                case .failure(let err):
                    self?.view?.showError(err.localizedDescription)
                }
            }
        }
    }
}
