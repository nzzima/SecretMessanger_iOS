//
//  EditProfileView.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 26.02.2025.
//

import Foundation
import FirebaseFirestore
import UIKit

protocol EditProfileViewProtocol: AnyObject {
    func fill(login: String, name: String, someInfo: String)
    func fill(avatar: UIImage?)
    func saved()
    func showError(_ message: String)
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
    
    let loginLabel: UILabel = {
        $0.text = "Логин"
        $0.textColor = .lightGray
        return $0
    }(UILabel())
    
    let nameLabel: UILabel = {
        $0.text = "Имя"
        $0.textColor = .lightGray
        return $0
    }(UILabel())
    
    let someInfoLabel: UILabel = {
        $0.text = "Заметка"
        $0.textColor = .lightGray
        return $0
    }(UILabel())
    
    lazy var editAvatar: UIButton = {
        $0.setTitle("Изменить аватар", for: .normal)
        $0.setTitleColor(.faceid, for: .normal)
        $0.addTarget(self, action: #selector(tappedEditAvatar), for: .touchUpInside)
        return $0
    }(UIButton())
    
    lazy var exitAccount: UIButton = {
        $0.setTitle("Выйти", for: .normal)
        $0.setTitleColor(.red, for: .normal)
        $0.addTarget(self, action: #selector(tappedExitAccount), for: .touchUpInside)
        return $0
    }(UIButton())
    
    lazy var rigthBarButton: UIButton = {
        $0.setTitle("Сохранить", for: .normal)
        $0.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        //$0.imageView?.contentMode = .scaleAspectFit
        $0.addTarget(self, action: #selector(saveChanges(_:)), for: .touchUpInside)
        return $0
    }(UIButton())
    
    //MARK: Логин виден собеседникам и участвует в реестре занятых имён, поэтому
    // клавиатура тут только латинская — как на регистрации.
    private lazy var loginField: UITextField = TextField(fieldPlaceholder: "Логин", keyboardType: .asciiCapable)
    private lazy var nameField: UITextField = TextField(fieldPlaceholder: "Введите новое имя")
    private lazy var someInfoField: UITextField = TextField(fieldPlaceholder: "Введите новую заметку")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .bgMain
        navigationItem.title = "Редактирование"
        let itemRightBar = UIBarButtonItem(customView: rigthBarButton)
        navigationItem.rightBarButtonItem = itemRightBar
        view.addSubviews(imageView, editAvatar, loginField, loginLabel, nameField, nameLabel, someInfoField, someInfoLabel, exitAccount)

        self.hideKeyboardWhenTappedAround()
        setConstraints()
    }
    
    @objc func tappedEditAvatar() {
        presentPhotoActionSheet()
    }
    
    @objc func tappedExitAccount() {
        presentExitActionSheet()
    }
    
    @objc func saveChanges(_ sender: UIBarButtonItem) {
        presenter.save(login: loginField.text ?? "",
                       name: nameField.text ?? "",
                       someInfo: someInfoField.text ?? "")
    }
    
    func fill(login: String, name: String, someInfo: String) {
        loginField.text = login
        nameField.text = name
        someInfoField.text = someInfo
    }

    //MARK: `nil` — аватара нет, и на его месте общая заглушка. Отдельного «пустого»
    // изображения для этого не заводим: тот же `basicUserImage` стоит во всех местах,
    // где человек без фото.
    func fill(avatar: UIImage?) {
        imageView.image = avatar ?? UIImage(named: "basicUserImage")
    }
    
    //MARK: Возвращаемся в профиль: он слушает свой документ и покажет новое сразу,
    // а оставлять человека на форме после успеха незачем.
    func saved() {
        navigationController?.popViewController(animated: true)
    }
    
    func showError(_ message: String) {
        showErrorAlert(message)
    }
    
    private func setConstraints() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        editAvatar.translatesAutoresizingMaskIntoConstraints = false
        loginLabel.translatesAutoresizingMaskIntoConstraints = false
        loginField.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        someInfoField.translatesAutoresizingMaskIntoConstraints = false
        someInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        exitAccount.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 120),
            imageView.heightAnchor.constraint(equalToConstant: 120),
            
            editAvatar.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 10),
            editAvatar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            editAvatar.heightAnchor.constraint(equalToConstant: 40),
            editAvatar.widthAnchor.constraint(equalToConstant: 150),
            
            loginLabel.bottomAnchor.constraint(equalTo: loginField.topAnchor, constant: -5),
            loginLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loginLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            loginLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            
            loginField.topAnchor.constraint(equalTo: editAvatar.bottomAnchor, constant: 40),
            loginField.heightAnchor.constraint(equalToConstant: 40),
            loginField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            loginField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            
            nameLabel.bottomAnchor.constraint(equalTo: nameField.topAnchor, constant: -5),
            nameLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            nameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            nameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            
            nameField.topAnchor.constraint(equalTo: loginField.bottomAnchor, constant: 40),
            nameField.heightAnchor.constraint(equalToConstant: 40),
            nameField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            nameField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            
            someInfoLabel.bottomAnchor.constraint(equalTo: someInfoField.topAnchor, constant: -5),
            someInfoLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            someInfoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            someInfoLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            
            someInfoField.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 40),
            someInfoField.heightAnchor.constraint(equalToConstant: 40),
            someInfoField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            someInfoField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            
            exitAccount.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            exitAccount.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            exitAccount.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            exitAccount.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30)
            
        ])
    }
}

extension EditProfileView: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func presentExitActionSheet() {
        let actionSheet = UIAlertController(title: "Вы действительно хотите выйти?", message: "", preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Отмена",
                                            style: .cancel,
                                            handler: nil))
        actionSheet.addAction(UIAlertAction(title: "Выйти из аккаунта",
                                            style: .default,
                                            handler: { [weak self] _ in
            self?.presentExit()
        }))
        
        present(actionSheet, animated: true)
    }
    
    func presentPhotoActionSheet() {
        let actionSheet = UIAlertController(title: "Аватар профиля", message: "", preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Отмена",
                                            style: .cancel,
                                            handler: nil))

        //MARK: Камеры на симуляторе нет вовсе, и без этой проверки пункт открывал бы
        // пустой чёрный экран без единой кнопки.
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            actionSheet.addAction(UIAlertAction(title: "Сделать фото",
                                                style: .default,
                                                handler: { [weak self] _ in
                self?.presentCamera()
            }))
        }

        actionSheet.addAction(UIAlertAction(title: "Выбрать фото",
                                            style: .default,
                                            handler: { [weak self] _ in
            self?.presentPhotoPicker()
        }))

        //MARK: Убрать фото предлагаем только тому, у кого оно есть: пункт, который
        // ничего не делает, — та же ложь, что кнопка без реакции.
        if presenter.hasAvatar {
            actionSheet.addAction(UIAlertAction(title: "Убрать фото",
                                                style: .destructive,
                                                handler: { [weak self] _ in
                self?.presenter.removeAvatar()
            }))
        }

        present(actionSheet, animated: true)
    }

    func presentCamera() {
        let vc = UIImagePickerController()
        vc.delegate = self
        vc.sourceType = .camera
        vc.allowsEditing = true
        present(vc, animated: true)
    }

    func presentPhotoPicker() {
        let vc = UIImagePickerController()
        vc.delegate = self
        vc.sourceType = .photoLibrary
        vc.allowsEditing = true
        present(vc, animated: true)
    }
    
    func presentExit() {
        FirebaseManager.shared.signOut()
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    //MARK: Берём отредактированную картинку, а не оригинал: `allowsEditing` даёт
    // системную рамку кадрирования, и человек уже выбрал ею, что попадёт в кружок.
    // Оригинал на всякий случай запасным вариантом — редактор можно и пропустить.
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)

        let picked = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage

        guard let picked else {
            showError("Не удалось прочитать изображение")
            return
        }

        presenter.changeAvatar(picked)
    }
}
