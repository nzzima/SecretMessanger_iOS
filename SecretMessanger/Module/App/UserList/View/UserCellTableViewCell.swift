//
//  UserCellTableViewCell.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 21.02.2025.
//

import UIKit

class UserCellTableViewCell: UITableViewCell {
    
    @IBOutlet weak var parentView: UIView!
    @IBOutlet weak var userLogin: UILabel!
    @IBOutlet weak var userImage: UIImageView!
    
    static let reuseIdentifier = "UserCellTableViewCell"

    //MARK: Чей аватар ячейка ждёт прямо сейчас. Ячейки переиспользуются, и пока
    // картинка едет, та же самая ячейка успевает уехать под другого человека —
    // без этой проверки в списке появлялись бы чужие лица.
    private var awaitedUid: String?

    override func awakeFromNib() {
        super.awakeFromNib()
        settingCell()
    }

    func configCell(_ user: ChatUser) {
        userLogin.text = user.login

        awaitedUid = user.id

        //MARK: Кэш спрашиваем синхронно: у большинства ячеек картинка уже есть, и
        // асинхронный заказ ради неё означал бы мигание заглушкой на каждой прокрутке.
        if let cached = AvatarStore.shared.cached(uid: user.id, version: user.avatarVersion) {
            userImage.image = cached
            return
        }

        userImage.image = UIImage(named: "basicUserImage")

        AvatarStore.shared.load(uid: user.id, version: user.avatarVersion) { [weak self] image in
            guard let self, let image, self.awaitedUid == user.id else { return }

            self.userImage.image = image
        }
    }

    func settingCell() {
        parentView.layer.cornerRadius = 10
        parentView.layer.borderColor = UIColor.lightGray.cgColor
        parentView.layer.borderWidth = 0.5
        userImage.layer.cornerRadius = userImage.frame.width / 2
        userImage.image = UIImage(named: "basicUserImage")
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
