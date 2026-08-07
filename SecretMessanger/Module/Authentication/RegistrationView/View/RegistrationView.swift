//
//  RegistrationView.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 07.08.2026.
//

import UIKit

protocol RegistrationViewProtocol: AnyObject {
    func showError(_ message: String)
}

class RegistrationView: UIViewController, RegistrationViewProtocol {

    var presenter: RegistrationViewPresenterProtocol!

    func showError(_ message: String) {
        showErrorAlert(message)
    }

    let pageTitle: UILabel = {
        $0.text = "Регистрация"
        $0.textColor = .white
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.font = UIFont(name: "Copperplate", size: 26)
        return $0
    }(UILabel())

    private lazy var emailField: UITextField = TextField(fieldPlaceholder: "Email", keyboardType: .emailAddress)
    private lazy var loginField: UITextField = TextField(fieldPlaceholder: "Логин", keyboardType: .asciiCapable)
    private lazy var passwordField: UITextField = TextField(fieldPlaceholder: "Пароль", isPassword: true)
    private lazy var passwordRepeatField: UITextField = TextField(fieldPlaceholder: "Повторите пароль", isPassword: true)

    private lazy var registrationButton: UIButton = Button(buttonText: "Зарегистрироваться", buttonImage: UIImage()) { [weak self] in
        guard let self else { return }

        presenter.register(email: emailField.text ?? "",
                           login: loginField.text ?? "",
                           password: passwordField.text ?? "",
                           passwordRepeat: passwordRepeatField.text ?? "")
    }

    private lazy var toAuthorizationButton: UIButton = {
        $0.setTitle("Уже есть аккаунт? Войти", for: .normal)
        $0.setTitleColor(.faceid, for: .normal)
        $0.titleLabel?.font = .systemFont(ofSize: 15)
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.addAction(UIAction(handler: { [weak self] _ in
            self?.presenter.goToAuthorization()
        }), for: .touchUpInside)
        return $0
    }(UIButton())

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .bgMain
        self.hideKeyboardWhenTappedAround()

        view.addSubviews(pageTitle, emailField, loginField, passwordField, passwordRepeatField, registrationButton, toAuthorizationButton)

        setConstraints()
    }

    private func setConstraints() {
        NSLayoutConstraint.activate([
            pageTitle.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 100),
            pageTitle.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            emailField.heightAnchor.constraint(equalToConstant: 50),
            emailField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            emailField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            emailField.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -100),

            loginField.topAnchor.constraint(equalTo: emailField.bottomAnchor, constant: 20),
            loginField.heightAnchor.constraint(equalToConstant: 50),
            loginField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            loginField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),

            passwordField.topAnchor.constraint(equalTo: loginField.bottomAnchor, constant: 20),
            passwordField.heightAnchor.constraint(equalToConstant: 50),
            passwordField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            passwordField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),

            passwordRepeatField.topAnchor.constraint(equalTo: passwordField.bottomAnchor, constant: 20),
            passwordRepeatField.heightAnchor.constraint(equalToConstant: 50),
            passwordRepeatField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            passwordRepeatField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),

            registrationButton.topAnchor.constraint(equalTo: passwordRepeatField.bottomAnchor, constant: 40),
            registrationButton.heightAnchor.constraint(equalToConstant: 40),
            registrationButton.widthAnchor.constraint(equalToConstant: 220),
            registrationButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            toAuthorizationButton.topAnchor.constraint(equalTo: registrationButton.bottomAnchor, constant: 20),
            toAuthorizationButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
}
