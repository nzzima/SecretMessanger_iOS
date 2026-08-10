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
    func reloadTitle()
    func showError(_ message: String)
}

class MessangerView: MessagesViewController, MessangerViewProtocol {

    var presenter: MessangerViewPresenterProtocol!

    private let textAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]

    override func viewDidLoad() {
        super.viewDidLoad()

        title = presenter.title
        navigationController?.navigationBar.titleTextAttributes = textAttributes
        showMessageTimestampOnSwipeLeft = true

        //MARK: Кнопка только в группе. Диалог на двоих третьим не дополняется: его
        // id — пара uid по алфавиту, и чат из «Контактов» всегда попадает именно в
        // него. Дописав туда третьего, мы получили бы группу, в которую эти двое
        // проваливаются каждый раз, когда просто хотят написать друг другу.
        if presenter.isGroup {
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "person.2"),
                                                                style: .plain,
                                                                target: self,
                                                                action: #selector(showMembers))
        }

        settingMessanger()
    }

    @objc private func showMembers() {
        let members = Builder.getChatMembersView(chat: presenter.chat)
        navigationController?.pushViewController(members, animated: true)
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

    //MARK: Название группы — это её состав, поэтому оно меняется вместе с ним.
    func reloadTitle() {
        title = presenter.title
    }

    func showError(_ message: String) {
        showErrorAlert(message)
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

    //MARK: Имя отправителя нужно только в группе и только над чужими сообщениями:
    // в диалоге на двоих сторона бабла и аватар уже говорят, кто написал, а свои
    // сообщения подписывать незачем в любом случае.
    func messageTopLabelHeight(for message: any MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        showsSenderName(for: message) ? 18 : 0
    }

    func messageTopLabelAttributedText(for message: any MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        guard showsSenderName(for: message) else { return nil }

        return NSAttributedString(string: message.sender.displayName, attributes: [
            .font: UIFont.systemFont(ofSize: 13),
            .foregroundColor: UIColor.lightGray
        ])
    }

    private func showsSenderName(for message: any MessageType) -> Bool {
        presenter.isGroup && !isFromSelf(message)
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

    //MARK: Поле очищается только если сообщение приняли к отправке. Иначе набранное
    // пропадало бы вместе с неудачей — а человеку его перенабирать.
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard presenter.sendMessage(text: text) else { return }

        inputBar.inputTextView.text = ""
    }
}
