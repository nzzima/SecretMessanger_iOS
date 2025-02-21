//
//  UserProfileViewPresenter.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 21.02.2025.
//

import Foundation

protocol UserProfileViewPresenterProtocol: AnyObject {
    
}

class UserProfileViewPresenter: UserProfileViewPresenterProtocol {
    
    weak var view: UserProfileViewProtocol?
    
    private let userProfileManager = UserProfileManager()
    
    required init(view: any UserProfileViewProtocol) {
        self.view = view
    }
    
}
