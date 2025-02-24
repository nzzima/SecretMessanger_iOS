//
//  ProfileViewPresenter.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 30.01.2025.
//

import Foundation

protocol ProfileViewPresenterProtocol: AnyObject {
    var activeUser: [ActiveUser] {get set}
}

class ProfileViewPresenter: ProfileViewPresenterProtocol {
    weak var view: ProfileViewProtocol?
    
    private let profileManager = ProfileManager()
    
    var activeUser : [ActiveUser] = []
    
    required init(view: any ProfileViewProtocol) {
        self.view = view
        getActiveUser()
    }
    
    func getActiveUser() {
        profileManager.getActiveUser { [weak self] activeUser in
            guard let self = self else { return }
            self.activeUser = activeUser
            self.view?.reloadTable()
        }
    }
}
