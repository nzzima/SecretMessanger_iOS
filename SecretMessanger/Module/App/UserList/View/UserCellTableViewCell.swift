//
//  UserCellTableViewCell.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 21.02.2025.
//

import UIKit

/// Строка списка «Контакты»: аватар, логин и точка присутствия.
class UserCellTableViewCell: UITableViewCell {

    @IBOutlet weak var parentView: UIView!
    @IBOutlet weak var userLogin: UILabel!

    //MARK: Класс аутлета подменён в самом xib (`customClass`), поэтому загрузку и
    // подстановку аватара ячейка не пишет вовсе — этим занимается `AvatarImageView`.
    @IBOutlet weak var userImage: AvatarImageView!

    //MARK: Точка живёт на `parentView`, а не внутри кружка: у `AvatarImageView`
    // включён `clipsToBounds`, и на самом аватаре её срезало бы ровно по краю круга —
    // то есть наполовину, потому что сидит она как раз на границе.
    private lazy var onlineDot: UIView = {
        //MARK: Зелёный здесь смысловой, а не акцентный: он значит «в сети» и больше
        // ничего. Акцент в приложении один и синий.
        $0.backgroundColor = .online
        $0.layer.cornerRadius = UserCellTableViewCell.dotDiameter / 2
        $0.layer.borderWidth = 2
        $0.layer.borderColor = UIColor.bgMain.cgColor
        $0.isHidden = true
        $0.translatesAutoresizingMaskIntoConstraints = false
        return $0
    }(UIView())

    private static let dotDiameter: CGFloat = 14

    static let reuseIdentifier = "UserCellTableViewCell"

    override func awakeFromNib() {
        super.awakeFromNib()
        settingCell()
    }

    //MARK: Присутствие приходит отдельным параметром, а не полем `ChatUser`: контакт
    // читается из профиля, а присутствие — из своей коллекции, и живут они с разной
    // скоростью. Сложи их в один тип — и каждый удар чужого пульса выглядел бы как
    // изменение контакта.
    /// Заполняет строку контакта.
    func configCell(_ user: ChatUser, isOnline: Bool) {
        userLogin.text = user.login
        onlineDot.isHidden = !isOnline

        userImage.load(uid: user.id, version: user.avatarVersion)
    }

    func settingCell() {
        parentView.addSubview(onlineDot)

        NSLayoutConstraint.activate([
            onlineDot.widthAnchor.constraint(equalToConstant: UserCellTableViewCell.dotDiameter),
            onlineDot.heightAnchor.constraint(equalToConstant: UserCellTableViewCell.dotDiameter),
            onlineDot.trailingAnchor.constraint(equalTo: userImage.trailingAnchor, constant: 2),
            onlineDot.bottomAnchor.constraint(equalTo: userImage.bottomAnchor, constant: 2)
        ])

        //MARK: Обводка убрана по той же причине, что и в списке чатов: рамка вокруг
        // каждой строки предлагала читать список как набор карточек, хотя это список.
        parentView.layer.cornerRadius = 10
        userImage.layer.cornerRadius = userImage.frame.width / 2
        userImage.showPlaceholder()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
