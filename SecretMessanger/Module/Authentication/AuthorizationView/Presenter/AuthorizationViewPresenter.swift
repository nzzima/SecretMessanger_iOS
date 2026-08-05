//
//  AuthorrizationViewPresenter.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 28.01.2025.
//

import Foundation
import UIKit

protocol AuthorizationViewPresenterProtocol: AnyObject {
    func signIn(userInfo: UserInfo)
}

class AuthorizationViewPresenter: AuthorizationViewPresenterProtocol {
    weak var view: AuthorizationViewProtocol?
    private let authenticationManager = AuthenticationManager()
    private let validator = FieldValidator()

    required init(view: any AuthorizationViewProtocol) {
        self.view = view
    }

    func signIn(userInfo: UserInfo) {
        guard validator.isValid(.email, userInfo.email) else {
            view?.showError("Проверьте адрес почты")
            return
        }

        guard validator.isValid(.password, userInfo.password) else {
            view?.showError("Пароль должен быть не короче 6 символов")
            return
        }

        authenticationManager.auth(userInfo: userInfo) { [weak self] result in
            //MARK: Firebase зовёт колбэк не с главного потока — и алерт, и смена окна
            // обязаны уйти на main, иначе UI просто не отреагирует.
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

}
