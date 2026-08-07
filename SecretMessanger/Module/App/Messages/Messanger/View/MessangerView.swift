//
//  MessangerView.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 04.08.2026.
//

import UIKit
import MessageKit
import InputBarAccessoryView

protocol MessangerViewProtocol: AnyObject {
    func reloadCollection()
}

class MessangerView: MessagesViewController, MessangerViewProtocol {

    var presenter: MessangerViewPresenterProtocol!

    private let textAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]

    override func viewDidLoad() {
        super.viewDidLoad()

        title = presenter.title
        navigationController?.navigationBar.titleTextAttributes = textAttributes
        showMessageTimestampOnSwipeLeft = true

        settingMessanger()
    }

    private func settingMessanger() {
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messageInputBar.delegate = self

        messagesCollectionView.backgroundColor = .bgMain
        view.backgroundColor = .bgMain

        settingInputBar()
    }

    //MARK: Панель ввода из MessageKit по умолчанию белая — на тёмном приложении она
    // выглядела чужой заплаткой. Фон берём `tabBar`: панель стоит вплотную к таб-бару
    // и должна читаться с ним как одна поверхность, а не спорить с ней.
    private func settingInputBar() {
        messageInputBar.backgroundView.backgroundColor = .tabBar
        messageInputBar.separatorLine.backgroundColor = .darkGray
        messageInputBar.padding = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)

        //MARK: Само поле повторяет текстовые поля авторизации: чёрный фон, белый текст,
        // серый плейсхолдер, скругление 15 — см. Helpers/TextField.
        messageInputBar.inputTextView.backgroundColor = .black
        messageInputBar.inputTextView.textColor = .white
        messageInputBar.inputTextView.tintColor = .systemBlue
        messageInputBar.inputTextView.font = .systemFont(ofSize: 16)
        messageInputBar.inputTextView.keyboardAppearance = .dark
        messageInputBar.inputTextView.placeholder = "Сообщение"
        messageInputBar.inputTextView.placeholderTextColor = .gray
        messageInputBar.inputTextView.layer.cornerRadius = 15
        messageInputBar.inputTextView.layer.masksToBounds = true
        messageInputBar.inputTextView.textContainerInset = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        messageInputBar.inputTextView.placeholderLabelInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)

        //MARK: Отправка — иконкой, как остальные действия в приложении
        // (`message`, `square.and.pencil`), а не английским словом Send посреди
        // русского интерфейса.
        messageInputBar.sendButton.title = nil
        messageInputBar.sendButton.image = UIImage(systemName: "arrow.up.circle.fill")
        messageInputBar.sendButton.imageView?.contentMode = .scaleAspectFit
        messageInputBar.sendButton.setSize(CGSize(width: 36, height: 36), animated: false)
        messageInputBar.sendButton.onEnabled { $0.tintColor = .systemBlue }
        messageInputBar.sendButton.onDisabled { $0.tintColor = .darkGray }

        //MARK: Хуки срабатывают только на смену состояния, а кнопка создаётся уже
        // выключенной — до первого введённого символа она осталась бы с дефолтным
        // цветом. Красим по текущему состоянию.
        messageInputBar.sendButton.tintColor = messageInputBar.sendButton.isEnabled ? .systemBlue : .darkGray
    }

    func reloadCollection() {
        messagesCollectionView.reloadData()

        guard !presenter.messages.isEmpty else { return }
        messagesCollectionView.scrollToLastItem(animated: false)
    }
}

extension MessangerView: MessagesDataSource {

    var currentSender: any SenderType {
        presenter.selfSender
    }

    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        presenter.messages[indexPath.section]
    }

    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        presenter.messages.count
    }
}

extension MessangerView: MessagesDisplayDelegate, MessagesLayoutDelegate {

    //MARK: Имя отправителя над баблом не выводим: в диалоге на двоих сторона бабла и
    // аватар уже говорят, кто написал, а подпись над каждым сообщением только
    // засоряет переписку.
    func messageTopLabelHeight(for message: any MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        0
    }

    //MARK: Высота от низа бабла до времени
    func messageBottomLabelHeight(for message: any MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        20
    }

    func backgroundColor(for message: any MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        isFromSelf(message) ? .systemBlue : .darkGray
    }

    func textColor(for message: any MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        .white
    }

    func messageBottomLabelAttributedText(for message: any MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        NSAttributedString(string: message.sentDate.formatted(date: .omitted, time: .shortened), attributes: [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.gray
        ])
    }

    func configureAvatarView(_ avatarView: AvatarView, for message: any MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        avatarView.initials = message.sender.displayName.first?.uppercased() ?? "?"
        avatarView.backgroundColor = isFromSelf(message) ? .systemBlue : .darkGray
    }

    private func isFromSelf(_ message: any MessageType) -> Bool {
        message.sender.senderId == presenter.selfSender.senderId
    }
}

extension MessangerView: InputBarAccessoryViewDelegate {

    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        presenter.sendMessage(text: text)
        inputBar.inputTextView.text = ""
    }
}
