//
//  EditProfileViewPresenter.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 26.02.2025.
//

import Foundation

protocol EditProfileViewPresenterProtocol: AnyObject {
    
}

class EditProfileViewPresenter: EditProfileViewPresenterProtocol {
    
    weak var view: EditProfileViewProtocol?
    
    required init(view: any EditProfileViewProtocol) {
        self.view = view
    }
}
