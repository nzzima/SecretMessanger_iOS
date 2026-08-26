//
//  AuthorizationView.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 28.01.2025.
//

import UIKit

protocol AuthorizationViewProtocol: AnyObject {
    func showError(_ message: String)
}

class AuthorizationView: UIViewController, AuthorizationViewProtocol {

    func showError(_ message: String) {
        showErrorAlert(message)
    }
    
    var presenter: AuthorizationViewPresenterProtocol!
    
    let pageTitle: UILabel = {
        $0.text = "Авторизация"
        $0.textColor = .ink
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.font = UIFont(name: "Copperplate", size: 26)
        return $0
    }(UILabel())
    
    private lazy var emailField:UITextField = TextField(fieldPlaceholder: "Email", keyboardType: .emailAddress)
    private lazy var passwordField:UITextField = TextField(fieldPlaceholder: "Пароль", isPassword: true)
    
    private lazy var authorizationButton:UIButton = Button(buttonText: "Войти", buttonImage: UIImage()) { [weak self] in
        guard let self = self else { return }
            
        let userInfo = UserInfo(email: emailField.text ?? "", password: passwordField.text ?? "")

        presenter.signIn(userInfo: userInfo)
        }
    
    private lazy var toRegistrationButton: UIButton = {
        $0.setTitle("Нет аккаунта? Зарегистрироваться", for: .normal)
        $0.setTitleColor(.accent, for: .normal)
        $0.titleLabel?.font = .systemFont(ofSize: 15)
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.addAction(UIAction(handler: { _ in
            NotificationCenter.default.post(name: .windowManager, object: nil, userInfo: [String.state: WindowManager.registrationWindow])
        }), for: .touchUpInside)
        return $0
    }(UIButton())

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .bgMain
        self.hideKeyboardWhenTappedAround()

        view.addSubviews(pageTitle, emailField, passwordField, authorizationButton, toRegistrationButton)

        setConstraints()
    }
    
    private func setConstraints() {
        NSLayoutConstraint.activate([
            pageTitle.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 100),
            pageTitle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            emailField.heightAnchor.constraint(equalToConstant: 50),
            emailField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            emailField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            emailField.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            
            passwordField.topAnchor.constraint(equalTo: emailField.bottomAnchor, constant: 20),
            passwordField.heightAnchor.constraint(equalToConstant: 50),
            passwordField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            passwordField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),

            authorizationButton.topAnchor.constraint(equalTo: passwordField.bottomAnchor, constant: 50),
            authorizationButton.heightAnchor.constraint(equalToConstant: 40),
            authorizationButton.widthAnchor.constraint(equalToConstant: 150),
            authorizationButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            toRegistrationButton.topAnchor.constraint(equalTo: authorizationButton.bottomAnchor, constant: 20),
            toRegistrationButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
}
