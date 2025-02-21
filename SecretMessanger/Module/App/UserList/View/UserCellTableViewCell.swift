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

    override func awakeFromNib() {
        super.awakeFromNib()
        settingCell()
    }
    
    func configCell(_ login: String) {
        userLogin.text = login
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
