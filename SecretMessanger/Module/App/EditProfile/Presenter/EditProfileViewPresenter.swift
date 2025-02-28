//
//  EditProfileViewPresenter.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 26.02.2025.
//

import Foundation

protocol EditProfileViewPresenterProtocol: AnyObject {
    var name: String {get set}
    var someInfo: String {get set}
}

class EditProfileViewPresenter: EditProfileViewPresenterProtocol {
    
    weak var view: EditProfileViewProtocol?
    
    private let editProfileManager = EditProfileManager()
    
    var name: String = ""
    var someInfo: String = ""
    
    required init(view: any EditProfileViewProtocol) {
        self.view = view
        
        getActiveUserName()
        getActiveUserSomeInfo()
    }
    
    func getActiveUserName() {
        editProfileManager.getActiveUserName { name in
            //guard let self = self else { return }
            self.name = name
        }
    }
    
    func getActiveUserSomeInfo() {
        editProfileManager.getActiveUserSomeInfo { someInfo in
            //guard let self = self else { return }
            self.someInfo = someInfo
        }
    }
}
