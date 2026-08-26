//
//  ConversationTableViewCell.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 04.08.2026.
//

import UIKit

//MARK: Свёрстана кодом, без xib — в отличие от UserCellTableViewCell. Ячейка здесь
// сложнее (три подписи вместо одной), и держать её в коде проще, чем в xib.
class ConversationTableViewCell: UITableViewCell {

    static let reuseIdentifier = "ConversationTableViewCell"

    //MARK: Обводка убрана. Карточка вокруг каждой строки спорила с самим списком: он
    // и так последовательность строк, а рамка предлагала читать их как отдельные
    // объекты. Разделяет их теперь волосяная линия — её рисует сама таблица.
    private let parentView: UIView = {
        $0.layer.cornerRadius = 10
        $0.translatesAutoresizingMaskIntoConstraints = false
        return $0
    }(UIView())

    private let userImage = AvatarImageView.cell()

    private let loginLabel: UILabel = {
        $0.textColor = .ink
        $0.font = .systemFont(ofSize: 17, weight: .semibold)
        $0.translatesAutoresizingMaskIntoConstraints = false
        return $0
    }(UILabel())

    private let lastMessageLabel: UILabel = {
        $0.textColor = .inkDim
        $0.font = .systemFont(ofSize: 14)
        $0.translatesAutoresizingMaskIntoConstraints = false
        return $0
    }(UILabel())

    private let dateLabel: UILabel = {
        $0.textColor = .inkDim

        //MARK: Моноширинные цифры: без них время в столбце пляшет по горизонтали от
        // строки к строке, потому что «1» уже «0».
        $0.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        $0.textAlignment = .right
        $0.translatesAutoresizingMaskIntoConstraints = false
        return $0
    }(UILabel())

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        settingCell()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Заполняет строку списка.
    ///
    /// - Parameters:
    ///   - conversation: диалог: название, превью и время.
    ///   - avatarVersion: версия аватара собеседника; для группы не используется.
    func configCell(_ conversation: Conversation, avatarVersion: Int) {
        loginLabel.text = conversation.title
        lastMessageLabel.text = conversation.lastMessage.truncate(to: 40)
        dateLabel.text = conversation.date.formatted(date: .omitted, time: .shortened)

        //MARK: У группы собеседник не один — там значок, а не чьё-то лицо.
        guard let uid = conversation.companionId else {
            userImage.showGroup()
            return
        }

        userImage.load(uid: uid, version: avatarVersion)
    }

    private func settingCell() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        contentView.addSubviews(parentView)
        parentView.addSubviews(userImage, loginLabel, lastMessageLabel, dateLabel)

        setConstraints()
    }

    private func setConstraints() {
        NSLayoutConstraint.activate([
            parentView.topAnchor.constraint(equalTo: contentView.topAnchor),
            parentView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            parentView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            parentView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            userImage.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: 16),
            userImage.centerYAnchor.constraint(equalTo: parentView.centerYAnchor),
            userImage.widthAnchor.constraint(equalToConstant: AvatarImageView.cellDiameter),
            userImage.heightAnchor.constraint(equalToConstant: AvatarImageView.cellDiameter),

            loginLabel.topAnchor.constraint(equalTo: userImage.topAnchor),
            loginLabel.leadingAnchor.constraint(equalTo: userImage.trailingAnchor, constant: 12),
            loginLabel.trailingAnchor.constraint(lessThanOrEqualTo: dateLabel.leadingAnchor, constant: -10),

            dateLabel.centerYAnchor.constraint(equalTo: loginLabel.centerYAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -16),

            lastMessageLabel.topAnchor.constraint(equalTo: loginLabel.bottomAnchor, constant: 2),
            lastMessageLabel.leadingAnchor.constraint(equalTo: loginLabel.leadingAnchor),
            lastMessageLabel.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -16)
        ])
    }
}
