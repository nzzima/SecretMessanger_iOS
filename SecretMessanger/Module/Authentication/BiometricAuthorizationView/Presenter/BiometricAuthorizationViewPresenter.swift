//
//  BiometricAuthorizationViewPresenter.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 28.01.2025.
//

import Foundation

protocol BiometricAuthorizationViewPresenterProtocol: AnyObject {
    init(view: BiometricAuthorizationViewProtocol)
}

class BiometricAuthorizationViewPresenter: BiometricAuthorizationViewPresenterProtocol {
    
    weak var view: BiometricAuthorizationViewProtocol?
    
    required init(view: any BiometricAuthorizationViewProtocol) {
        self.view = view
    }
}
