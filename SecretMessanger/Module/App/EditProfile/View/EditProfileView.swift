//
//  EditProfileView.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 26.02.2025.
//

import Foundation
import UIKit

protocol EditProfileViewProtocol: AnyObject {
    
}

class EditProfileView: UIViewController, EditProfileViewProtocol {
    
    var presenter: EditProfileViewPresenterProtocol!
    
    lazy var imageView: UIImageView = {
        $0.image = UIImage(named: "basicUserImage")
        $0.contentMode = .scaleAspectFill
        $0.layer.borderWidth = 4
        $0.layer.borderColor = UIColor.gray.cgColor
        $0.clipsToBounds = true
        $0.layer.masksToBounds = true
        $0.layer.cornerRadius = 50
        return $0
    }(UIImageView())
    
    lazy var editAvatar: UIButton = {
        $0.setTitle("Изменить аватар", for: .normal)
        $0.setTitleColor(.faceid, for: .normal)
        $0.addTarget(self, action: #selector(tappedEditAvatar), for: .touchUpInside)
        return $0
    }(UIButton())
    
    private lazy var nameField: UITextField = TextField(fieldPlaceholder: "Name")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .bgMain
        navigationItem.title = "Редактирование"
        view.addSubviews(imageView, editAvatar, nameField)
        
        setConstraints()
    }
    
    @objc func tappedEditAvatar() {
        print("Tapped edit avatar")
    }
    
    private func setConstraints() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        editAvatar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 120),
            imageView.heightAnchor.constraint(equalToConstant: 120),
            
            editAvatar.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 10),
            editAvatar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            editAvatar.heightAnchor.constraint(equalToConstant: 40),
            editAvatar.widthAnchor.constraint(equalToConstant: 150),
            
            nameField.topAnchor.constraint(equalTo: editAvatar.bottomAnchor, constant: 40),
            nameField.heightAnchor.constraint(equalToConstant: 40),
            nameField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            nameField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
        ])
    }
}
