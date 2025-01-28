//
//  AuthorrizationViewPresenter.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 28.01.2025.
//

import Foundation

protocol AuthorizationViewPresenterProtocol: AnyObject {
    init(view: AuthorizationViewProtocol)
}

class AuthorizationViewPresenter: AuthorizationViewPresenterProtocol {
    weak var view: AuthorizationViewProtocol?
    
    required init(view: any AuthorizationViewProtocol) {
        self.view = view
    }
    
    
}
