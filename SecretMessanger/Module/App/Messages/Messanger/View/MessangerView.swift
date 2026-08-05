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

    //MARK: Высота от верха бабла до имени отправителя
    func messageTopLabelHeight(for message: any MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        20
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

    func messageTopLabelAttributedText(for message: any MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        NSAttributedString(string: message.sender.displayName, attributes: [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.lightGray
        ])
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
