//
//  RegistrationViewPresenter.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 07.08.2026.
//

import Foundation

protocol RegistrationViewPresenterProtocol: AnyObject {
    func register(email: String, login: String, password: String, passwordRepeat: String)
    func goToAuthorization()
}

class RegistrationViewPresenter: RegistrationViewPresenterProtocol {

    weak var view: RegistrationViewProtocol?

    private let registrationManager = RegistrationManager()
    private let validator = FieldValidator()

    required init(view: any RegistrationViewProtocol) {
        self.view = view
    }

    func register(email: String, login: String, password: String, passwordRepeat: String) {
        guard validator.isValid(.email, email) else {
            view?.showError("Проверьте адрес почты")
            return
        }

        guard validator.isValid(.login, login) else {
            view?.showError("Логин — от 3 до 20 символов: латиница, цифры, подчёркивание")
            return
        }

        guard validator.isValid(.password, password) else {
            view?.showError("Пароль должен быть не короче 6 символов")
            return
        }

        //MARK: Опечатка в пароле при регистрации стоит дороже, чем при входе: аккаунт
        // уже создан, а войти в него не выйдет.
        guard password == passwordRepeat else {
            view?.showError("Пароли не совпадают")
            return
        }

        registrationManager.createUser(email: email, password: password, login: login) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    NotificationCenter.default.post(name: .windowManager, object: nil, userInfo: [String.state: WindowManager.appWindow])
                case .failure(let err):
                    self?.view?.showError(err.localizedDescription)
                }
            }
        }
    }

    func goToAuthorization() {
        NotificationCenter.default.post(name: .windowManager, object: nil, userInfo: [String.state: WindowManager.authorizationWindow])
    }
}
