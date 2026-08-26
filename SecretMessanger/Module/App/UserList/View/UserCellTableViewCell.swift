//
//  UserCellTableViewCell.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 21.02.2025.
//

import UIKit

//MARK: Свёрстана кодом с 25.08.2026 — до этого была xib. Причина та же, по которой в
// коде живёт ConversationTableViewCell: подписей стало две, а не одна, и держать такую
// ячейку в xib дороже, чем в коде. Заодно обе строки списков теперь читаются рядом, и
// разъехаться их метрикам труднее.
/// Строка списка «Контакты»: аватар, логин и присутствие словами.
class UserCellTableViewCell: UITableViewCell {

    static let reuseIdentifier = "UserCellTableViewCell"

    private let userImage = AvatarImageView.cell()

    private let userLogin: UILabel = {
        $0.textColor = .ink
        $0.font = .systemFont(ofSize: 16, weight: .medium)
        $0.translatesAutoresizingMaskIntoConstraints = false
        return $0
    }(UILabel())

    //MARK: Присутствие словами вместо одной только точки. Точка отвечает лишь на «сейчас
    // или нет», а «в сети 20 минут назад» и «в сети 12 августа» — разные ответы, и
    // человеку важна именно разница между ними. Точка при этом остаётся: она читается
    // мгновенно и не требует читать строку.
    private let presenceLabel: UILabel = {
        $0.font = .systemFont(ofSize: 13)
        $0.translatesAutoresizingMaskIntoConstraints = false
        return $0
    }(UILabel())

    //MARK: Точка живёт на `contentView`, а не внутри кружка: у `AvatarImageView` включён
    // `clipsToBounds`, и на самом аватаре её срезало бы ровно по краю круга — то есть
    // наполовину, потому что сидит она как раз на границе.
    private lazy var onlineDot: UIView = {
        //MARK: Зелёный здесь смысловой, а не акцентный: он значит «в сети» и больше
        // ничего. Акцент в приложении один и синий.
        $0.backgroundColor = .online
        $0.layer.cornerRadius = UserCellTableViewCell.dotDiameter / 2
        $0.layer.borderWidth = 2.5
        $0.layer.borderColor = UIColor.bgMain.cgColor
        $0.isHidden = true
        $0.translatesAutoresizingMaskIntoConstraints = false
        return $0
    }(UIView())

    private static let dotDiameter: CGFloat = 13

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        settingCell()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    //MARK: Присутствие приходит отдельными параметрами, а не полем `ChatUser`: контакт
    // читается из профиля, а присутствие — из своей коллекции, и живут они с разной
    // скоростью. Сложи их в один тип — и каждый удар чужого пульса выглядел бы как
    // изменение контакта.
    /// Заполняет строку контакта.
    ///
    /// - Parameters:
    ///   - presence: подпись присутствия; пустая строка — «не знаем», а не «офлайн»:
    ///     человек, ни разу не заходивший после появления присутствия, документа не
    ///     имеет вовсе.
    ///   - isOnline: зажигать ли точку.
    func configCell(_ user: ChatUser, presence: String, isOnline: Bool) {
        userLogin.text = user.login

        presenceLabel.text = presence
        presenceLabel.isHidden = presence.isEmpty
        presenceLabel.textColor = isOnline ? .online : .inkDim

        onlineDot.isHidden = !isOnline

        userImage.load(uid: user.id, version: user.avatarVersion)
    }

    private func settingCell() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        contentView.addSubviews(userImage, userLogin, presenceLabel, onlineDot)

        setConstraints()
    }

    //MARK: Подписи собраны вокруг центра аватара, а не растянуты по строке: у контакта
    // без присутствия вторая строка прячется, и одинокий логин обязан остаться по
    // центру, а не повиснуть выше него.
    private func setConstraints() {
        let stack = UIStackView(arrangedSubviews: [userLogin, presenceLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            userImage.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            userImage.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            userImage.widthAnchor.constraint(equalToConstant: AvatarImageView.cellDiameter),
            userImage.heightAnchor.constraint(equalToConstant: AvatarImageView.cellDiameter),

            stack.leadingAnchor.constraint(equalTo: userImage.trailingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            onlineDot.widthAnchor.constraint(equalToConstant: UserCellTableViewCell.dotDiameter),
            onlineDot.heightAnchor.constraint(equalToConstant: UserCellTableViewCell.dotDiameter),
            onlineDot.trailingAnchor.constraint(equalTo: userImage.trailingAnchor, constant: 1),
            onlineDot.bottomAnchor.constraint(equalTo: userImage.bottomAnchor, constant: 1)
        ])
    }
}
