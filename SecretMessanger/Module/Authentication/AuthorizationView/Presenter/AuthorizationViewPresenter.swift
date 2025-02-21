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
        if validator.isValid(.email, userInfo.email),
            validator.isValid(.password, userInfo.password) {
                authenticationManager.auth(userInfo: userInfo) { result in
                    switch result {
                    case .success(let success):
                        if success {
                            NotificationCenter.default.post(name: .windowManager, object: nil, userInfo: [String.state: WindowManager.appWindow])
                        }
                    case .failure(let failure):
                        print(failure.localizedDescription)
                    }
                }
            }
        }
    
}
