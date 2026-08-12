//
//  EditProfileViewPresenter.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 26.02.2025.
//

import UIKit

/// Форма правки своего профиля.
protocol EditProfileViewPresenterProtocol: AnyObject {
    /// Есть ли что убирать: от этого зависит пункт «Убрать фото» в меню.
    var hasAvatar: Bool { get }

    /// Сохраняет поля. Логин при изменении переносится в реестре занятых имён.
    func save(login: String, name: String, someInfo: String)

    /// Меняет аватар **сразу**, не дожидаясь «Сохранить»: он лежит в своём документе и
    /// ни с чем не связан, а ошибка валидации логина иначе теряла бы выбранное фото.
    func changeAvatar(_ image: UIImage)
    func removeAvatar()
}

class EditProfileViewPresenter: EditProfileViewPresenterProtocol {

    weak var view: EditProfileViewProtocol?

    private let editProfileManager = EditProfileManager()
    private let validator = FieldValidator()

    //MARK: Логин на момент открытия экрана. Нужен, чтобы понять, меняли его вообще
    // или человек правил только имя и заметку: во втором случае реестр трогать
    // незачем.
    private var currentLogin = ""

    //MARK: Версия аватара на момент открытия экрана: следующая запись пойдёт под
    // номером на единицу больше. Ноль — аватара нет, и «Убрать фото» экран не покажет.
    private var avatarVersion = 0

    //MARK: Пока запись идёт, вторую не начинаем: номер следующей версии считается от
    // текущей, а она станет известна только по возвращении. Два быстрых выбора подряд
    // иначе ушли бы под одним номером — и второй показывался бы из кэша первым.
    private var isSavingAvatar = false

    var hasAvatar: Bool { avatarVersion > 0 }

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
            self.avatarVersion = user.avatarVersion

            //MARK: Поля заполняются тем, что уже есть в профиле. Пустая форма
            // заставляла бы набирать заново даже то, что менять не собирались, — и
            // сохранение стёрло бы незаполненное.
            DispatchQueue.main.async {
                self.view?.fill(login: user.login, name: user.name, someInfo: user.someInfo)
            }

            AvatarStore.shared.load(uid: user.id, version: user.avatarVersion) { [weak self] image in
                self?.view?.fill(avatar: image)
            }
        }
    }

    // MARK: - Аватар

    //MARK: Аватар сохраняется сразу, а не по кнопке «Сохранить», и это осознанно.
    // Кнопка запускает трёхшаговую сделку с реестром логинов — занять новое имя,
    // переписать профиль, отпустить старое, — и вешать на неё ещё и загрузку картинки
    // значило бы терять выбранное фото на каждой ошибке валидации логина. Аватар лежит
    // в своём документе, ни с чем не связан, и повода ждать у него нет.
    func changeAvatar(_ image: UIImage) {
        guard let uid = FirebaseManager.shared.getUser()?.uid, !isSavingAvatar else { return }

        let version = avatarVersion + 1
        isSavingAvatar = true

        //MARK: Показываем выбранное сразу: загрузка занимает секунды, а кружок,
        // который эти секунды показывает старое фото, читается как «не сработало».
        view?.fill(avatar: image)

        AvatarStore.shared.save(image, uid: uid, version: version) { [weak self] err in
            guard let self else { return }

            guard err == nil else {
                self.isSavingAvatar = false
                self.view?.showError(err?.localizedDescription ?? "Аватар не сохранился")
                self.reloadAvatar(uid: uid)
                return
            }

            //MARK: Маркер пишется вторым: картинка к этому моменту уже лежит, и никто
            // не пойдёт за ней раньше, чем она появилась. Если маркер не запишется,
            // собеседники просто не узнают о смене — а не увидят пустое место.
            self.editProfileManager.saveAvatarVersion(version) { err in
                DispatchQueue.main.async {
                    self.isSavingAvatar = false

                    guard err == nil else {
                        self.view?.showError(err?.localizedDescription ?? "Аватар не сохранился")
                        return
                    }

                    self.avatarVersion = version
                }
            }
        }
    }

    //MARK: Удаление зеркально: сперва картинка, потом маркер. Обратный порядок оставил
    // бы в профиле ссылку на то, чего уже нет.
    func removeAvatar() {
        guard let uid = FirebaseManager.shared.getUser()?.uid, hasAvatar else { return }

        view?.fill(avatar: nil)

        AvatarStore.shared.remove(uid: uid) { [weak self] err in
            guard let self else { return }

            DispatchQueue.main.async {
                guard err == nil else {
                    self.view?.showError(err?.localizedDescription ?? "Аватар не удалился")
                    self.reloadAvatar(uid: uid)
                    return
                }

                self.editProfileManager.saveAvatarVersion(0) { err in
                    DispatchQueue.main.async {
                        guard err == nil else {
                            self.view?.showError(err?.localizedDescription ?? "Аватар не удалился")
                            return
                        }

                        self.avatarVersion = 0
                    }
                }
            }
        }
    }

    //MARK: Не получилось — возвращаем на экран то, что на самом деле лежит в базе.
    // Иначе кружок показывал бы картинку, которой там нет.
    private func reloadAvatar(uid: String) {
        AvatarStore.shared.load(uid: uid, version: avatarVersion) { [weak self] image in
            self?.view?.fill(avatar: image)
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
