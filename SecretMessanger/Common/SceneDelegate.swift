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
    
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        NotificationCenter.default.addObserver(self, selector: #selector(windowManager(notification:)), name: .windowManager, object: nil)
        
        guard let scene = (scene as? UIWindowScene) else { return }
        
        self.window = UIWindow(windowScene: scene)
        window?.rootViewController = Builder.getBiometricAuthorizationView()
        //window?.rootViewController = Builder.getProfileView()
        window?.makeKeyAndVisible()
    }
    
    @objc
    private func windowManager(notification: Notification) {
        
        guard let userInfo = notification.userInfo as? [String: Any] else { return }
        
        guard let state = userInfo[.state] as? WindowManager else {
            return
        }
        
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
    }

    func sceneWillResignActive(_ scene: UIScene) {
        //MARK: Пусто намеренно. Этот метод срабатывает на всякую мелочь — шторку
        // уведомлений, панель управления, входящий звонок, — и гасить человека на них
        // значило бы мигать серым по десять раз на дню. Уход считается по фону.
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        PresenceStore.shared.resume()
    }

    //MARK: Финальный удар пульса пишется здесь, а не в `resignActive`: именно этот момент
    // потом читается как «в сети 20 минут назад».
    func sceneDidEnterBackground(_ scene: UIScene) {
        PresenceStore.shared.pause()
    }
}
