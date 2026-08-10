//
//  EditProfileViewPresenter.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 26.02.2025.
//

import Foundation

protocol EditProfileViewPresenterProtocol: AnyObject {
    func save(login: String, name: String, someInfo: String)
}

class EditProfileViewPresenter: EditProfileViewPresenterProtocol {

    weak var view: EditProfileViewProtocol?

    private let editProfileManager = EditProfileManager()
    private let validator = FieldValidator()

    //MARK: Логин на момент открытия экрана. Нужен, чтобы понять, меняли его вообще
    // или человек правил только имя и заметку: во втором случае реестр трогать
    // незачем.
    private var currentLogin = ""

    required init(view: any EditProfileViewProtocol) {
        self.view = view

        getActiveUser()
    }

    private func getActiveUser() {
        //MARK: `[weak self]` здесь обязателен: без него замыкание удерживало презентер,
        // а слушатель, который её держал, никогда не снимался — экран не освобождался.
        editProfileManager.getActiveUser { [weak self] user in
            guard let self else { return }

            self.currentLogin = user.login

            //MARK: Поля заполняются тем, что уже есть в профиле. Пустая форма
            // заставляла бы набирать заново даже то, что менять не собирались, — и
            // сохранение стёрло бы незаполненное.
            DispatchQueue.main.async {
                self.view?.fill(login: user.login, name: user.name, someInfo: user.someInfo)
            }
        }
    }

    func save(login: String, name: String, someInfo: String) {
        let login = login.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let someInfo = someInfo.trimmingCharacters(in: .whitespacesAndNewlines)

        guard validator.isValid(.login, login) else {
            view?.showError("Логин — от 3 до 20 символов: латиница, цифры, подчёркивание")
            return
        }

        //MARK: Имя показывается собеседникам вместо логина, и пустым его оставлять
        // нельзя — иначе в контактах и заголовках чатов будет пусто.
        guard !name.isEmpty else {
            view?.showError("Имя не может быть пустым")
            return
        }

        editProfileManager.save(login: login, name: name, someInfo: someInfo,
                                currentLogin: currentLogin) { [weak self] err in
            DispatchQueue.main.async {
                guard let err else {
                    //MARK: Своё имя кэшируется, чтобы не читать профиль ради подписи
                    // под каждым сообщением, — после переименования кэш обязан
                    // догнать, иначе человек подписывался бы старым именем.
                    SelfName.current = login
                    self?.currentLogin = login
                    self?.view?.saved()
                    return
                }

                self?.view?.showError(err.localizedDescription)
            }
        }
    }
}
