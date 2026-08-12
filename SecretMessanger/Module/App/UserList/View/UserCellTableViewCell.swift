//
//  UserCellTableViewCell.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 21.02.2025.
//

import UIKit

/// Строка списка «Контакты»: аватар и логин.
class UserCellTableViewCell: UITableViewCell {

    @IBOutlet weak var parentView: UIView!
    @IBOutlet weak var userLogin: UILabel!

    //MARK: Класс аутлета подменён в самом xib (`customClass`), поэтому загрузку и
    // подстановку аватара ячейка не пишет вовсе — этим занимается `AvatarImageView`.
    @IBOutlet weak var userImage: AvatarImageView!

    static let reuseIdentifier = "UserCellTableViewCell"

    override func awakeFromNib() {
        super.awakeFromNib()
        settingCell()
    }

    /// Заполняет строку контакта.
    func configCell(_ user: ChatUser) {
        userLogin.text = user.login

        userImage.load(uid: user.id, version: user.avatarVersion)
    }

    func settingCell() {
        parentView.layer.cornerRadius = 10
        parentView.layer.borderColor = UIColor.lightGray.cgColor
        parentView.layer.borderWidth = 0.5
        userImage.layer.cornerRadius = userImage.frame.width / 2
        userImage.showPlaceholder()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
