//
//  ProfileViewPresenter.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 30.01.2025.
//

import Foundation

protocol ProfileViewPresenterProtocol: AnyObject {
    
}

class ProfileViewPresenter: ProfileViewPresenterProtocol {
    
    weak var view: ProfileViewProtocol?
    
    required init(view: any ProfileViewProtocol) {
        self.view = view
    }
}
