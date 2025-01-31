//
//  AuthorizationView.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 28.01.2025.
//

import UIKit

protocol AuthorizationViewProtocol: AnyObject {
    
}

class AuthorizationView: UIViewController, AuthorizationViewProtocol {
    
    var presenter: AuthorizationViewPresenterProtocol!
    
    let pageTitle: UILabel = {
        $0.text = "Авторизация"
        $0.textColor = .white
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.font = UIFont(name: "Copperplate", size: 26)
        return $0
    }(UILabel())
    
    private lazy var loginField:UITextField = TextField(fieldPlaceholder: "Логин")
    private lazy var passwordField:UITextField = TextField(fieldPlaceholder: "Пароль", isPassword: true)
    
    private lazy var authorizationButton:UIButton = Button(buttonText: "Войти", buttonImage: UIImage()) { [weak self] in
        guard let self = self else { return }
            
        let userInfo = UserInfo(login: loginField.text ?? "", password: passwordField.text ?? "")
        
        NotificationCenter.default.post(name: .windowManager, object: nil, userInfo: [String.state: WindowManager.appWindow])
        
        print("Authorization: \(userInfo.login) \(userInfo.password)")
            //presenter.signIn(userInfo: userInfo)
        }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .bgMain
        self.hideKeyboardWhenTappedAround()
        
        view.addSubviews(pageTitle, loginField, passwordField, authorizationButton)
        
        setConstraints()
    }
    
    private func setConstraints() {
        NSLayoutConstraint.activate([
            pageTitle.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 100),
            pageTitle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                
            loginField.heightAnchor.constraint(equalToConstant: 50),
            loginField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            loginField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            loginField.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            
            passwordField.heightAnchor.constraint(equalToConstant: 50),
            passwordField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            passwordField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            passwordField.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 30),
            
            authorizationButton.topAnchor.constraint(equalTo: passwordField.bottomAnchor, constant: 50),
            authorizationButton.heightAnchor.constraint(equalToConstant: 40),
            authorizationButton.widthAnchor.constraint(equalToConstant: 150),
            authorizationButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
}
