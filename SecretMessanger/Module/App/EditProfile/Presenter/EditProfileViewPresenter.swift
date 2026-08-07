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

        getActiveUser()
    }

    func getActiveUser() {
        //MARK: `[weak self]` здесь обязателен: без него замыкание удерживало презентер,
        // а слушатель, который её держал, никогда не снимался — экран не освобождался.
        editProfileManager.getActiveUser { [weak self] name, someInfo in
            guard let self else { return }

            self.name = name
            self.someInfo = someInfo
        }
    }
}
