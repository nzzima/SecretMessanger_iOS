//
//  SceneDelegate.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 28.01.2025.
//

import UIKit

enum WindowManager: String {
    case biometricWindow, authorizationWindow, registrationWindow, appWindow
}

enum UserInfoKeys: String {
    case state
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?

    //MARK: Что показано прямо сейчас. Нужно, чтобы не запирать уже запертое: вернувшись
    // на экран блокировки или на форму входа, мы переходом туда же сбросили бы наполовину
    // введённый пароль.
    private var currentWindow: WindowManager = .biometricWindow

    /// Когда ушли в фон. `nil` — не уходили.
    private var leftAt: Date?

    //MARK: Заслонка поверх окна. Снимок для переключателя задач система делает сама, и
    // без заслонки в нём осталась бы открытая переписка — видная всякому, кто дважды
    // нажмёт кнопку на разблокированном телефоне. Блокировка по возврату от этого не
    // спасает: снимок сделан раньше, чем мы что-либо спросим.
    private var shield: UIView?
    
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        NotificationCenter.default.addObserver(self, selector: #selector(windowManager(notification:)), name: .windowManager, object: nil)
        
        guard let scene = (scene as? UIWindowScene) else { return }
        
        self.window = UIWindow(windowScene: scene)
        window?.rootViewController = Builder.getBiometricAuthorizationView()
        //window?.rootViewController = Builder.getProfileView()
        window?.makeKeyAndVisible()

        currentWindow = .biometricWindow
    }
    
    @objc
    private func windowManager(notification: Notification) {
        
        guard let userInfo = notification.userInfo as? [String: Any] else { return }
        
        guard let state = userInfo[.state] as? WindowManager else {
            return
        }
        
        currentWindow = state

        switch state {
        case .biometricWindow:
            //MARK: Экран блокировки — это ещё не «человек в сети»: сессия Firebase живёт
            // месяцами, и без этой строки присутствие включалось бы до Face ID.
            PresenceStore.shared.deactivate()
            window?.rootViewController = Builder.getBiometricAuthorizationView()
        case .authorizationWindow:
            PresenceStore.shared.deactivate()
            window?.rootViewController = Builder.getAuthorizationView()
        case .registrationWindow:
            PresenceStore.shared.deactivate()
            window?.rootViewController = Builder.getRegistrationView()
        case .appWindow:
            //MARK: Единственная точка, после которой человек действительно в приложении:
            // вход выполнен и биометрия пройдена. Отсюда и начинается пульс.
            PresenceStore.shared.activate()
            window?.rootViewController = Builder.getTabBarView()
        }
    }

    //MARK: Эти четыре метода до 19.08.2026 лежали **вложенными функциями** внутри
    // `windowManager(notification:)` — то есть UIKit их не видел и не вызывал ни разу за
    // всё время жизни проекта. Приложение не знало ни что ушло в фон, ни что вернулось.
    // Пока они не выбрались на уровень класса, ни присутствие, ни блокировка по возврату
    // держаться было не на чем.
    func sceneDidDisconnect(_ scene: UIScene) {
        PresenceStore.shared.pause()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        PresenceStore.shared.resume()

        hideShield()
    }

    //MARK: Присутствие этот метод намеренно не трогает: он срабатывает на всякую мелочь —
    // шторку уведомлений, панель управления, входящий звонок, — и гасить человека на них
    // значило бы мигать серым по десять раз на дню. Уход из сети считается по фону.
    //
    // А заслонку ставить надо именно здесь: снимок для переключателя задач система делает
    // **до** `didEnterBackground`, и поставленная там заслонка в него уже не попадёт.
    // Мелькание при шторке уведомлений — плата за то, чтобы переписки в снимке не было
    // никогда.
    func sceneWillResignActive(_ scene: UIScene) {
        showShield()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        PresenceStore.shared.resume()

        //MARK: Порядок обязателен: сначала меняем окно, потом убираем заслонку — её снимет
        // `sceneDidBecomeActive` следом. Наоборот переписка мелькнула бы на кадр перед
        // экраном блокировки.
        if ReturnLock.shouldLock(state: currentWindow, leftAt: leftAt) {
            NotificationCenter.default.post(name: .windowManager,
                                            object: nil,
                                            userInfo: [String.state: WindowManager.biometricWindow])
        }

        leftAt = nil
    }

    //MARK: Финальный удар пульса пишется здесь, а не в `resignActive`: именно этот момент
    // потом читается как «в сети 20 минут назад». Здесь же засекается уход — по фону, а не
    // по потере активности: свернули в карман, а не открыли шторку.
    func sceneDidEnterBackground(_ scene: UIScene) {
        PresenceStore.shared.pause()

        leftAt = Date()
    }

    private func showShield() {
        guard shield == nil, let window else { return }

        let cover = UIView(frame: window.bounds)
        cover.backgroundColor = .bgMain
        cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let lock = UIImageView(image: UIImage(systemName: "lock.fill"))
        lock.tintColor = .accent
        lock.contentMode = .scaleAspectFit
        lock.translatesAutoresizingMaskIntoConstraints = false

        cover.addSubview(lock)

        NSLayoutConstraint.activate([
            lock.centerXAnchor.constraint(equalTo: cover.centerXAnchor),
            lock.centerYAnchor.constraint(equalTo: cover.centerYAnchor),
            lock.widthAnchor.constraint(equalToConstant: 64),
            lock.heightAnchor.constraint(equalToConstant: 64)
        ])

        window.addSubview(cover)
        shield = cover
    }

    private func hideShield() {
        shield?.removeFromSuperview()
        shield = nil
    }
}
