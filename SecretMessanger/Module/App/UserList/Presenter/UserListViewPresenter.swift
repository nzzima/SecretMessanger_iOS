//
//  UserListViewPresenter.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 30.01.2025.
//

import Foundation

protocol UserListViewPresenterProtocol: AnyObject {
    
}

class UserListViewPresenter: UserListViewPresenterProtocol {
    
    weak var view: UserListViewProtocol?
    
    required init(view: any UserListViewProtocol) {
        self.view = view
    }
}
