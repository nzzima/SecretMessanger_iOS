//
//  BiometricAuthorizationView.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 28.01.2025.
//

import UIKit
import LocalAuthentication
import Firebase

protocol BiometricAuthorizationViewProtocol: AnyObject {
    
}

class BiometricAuthorizationView: UIViewController, BiometricAuthorizationViewProtocol {
    
    var presenter: BiometricAuthorizationViewPresenterProtocol!
    
    let pageTitle1: UILabel = {
            $0.text = "Мессенджер"
            $0.textColor = .ink
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.font = UIFont(name: "Copperplate", size: 36)
            return $0
        }(UILabel())
    
    let pageTitle2: UILabel = {
            $0.text = "заблокирован"
            $0.textColor = .ink
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.font = UIFont(name: "Copperplate", size: 36)
            return $0
        }(UILabel())
    
    private lazy var biometricAuthButton:UIButton = Button(buttonText: " Face ID",buttonImage: UIImage(systemName: "faceid") ?? UIImage(), buttonColor: .white, titleColor: .accent) {
            self.authButtonPressed()
        }
    
    let faceIdImage: UIImageView = {
        $0.image = UIImage(systemName: "faceid")
        $0.tintColor = UIColor.accent
        $0.translatesAutoresizingMaskIntoConstraints = false
        return $0
    }(UIImageView())
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .bgMain
        view.addSubviews(pageTitle1, pageTitle2, biometricAuthButton)
        
        setConstraints()
    }
    
    private func setConstraints() {
        NSLayoutConstraint.activate([
            pageTitle1.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 100),
            pageTitle1.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            pageTitle2.topAnchor.constraint(equalTo: pageTitle1.bottomAnchor, constant: 0),
            pageTitle2.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                
            biometricAuthButton.topAnchor.constraint(equalTo: pageTitle1.bottomAnchor, constant: 200),
            biometricAuthButton.heightAnchor.constraint(equalToConstant: 40),
            biometricAuthButton.widthAnchor.constraint(equalToConstant: 150),
            biometricAuthButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    //MARK: Проверяется и выполняется **одна и та же** политика. До 24.08.2026 они
    // расходились: проверка шла по `.deviceOwnerAuthentication` («есть биометрия или
    // код-пароль»), а выполнение — по `.deviceOwnerAuthenticationWithBiometrics` («только
    // биометрия»). Расхождение запирало приложение наглухо. Достаточно было одного из
    // трёх: Face ID не настроен на телефоне, разрешение приложению отклонили при
    // единственном системном запросе, биометрия заблокирована после пяти промахов. Во всех
    // трёх проверка проходила, вход падал, и человек получал «Попробуйте снова» столько
    // раз, сколько готов был нажимать: другого пути внутрь на этом экране нет.
    //
    // `.deviceOwnerAuthentication` позволяет системе предложить код-пароль устройства,
    // когда биометрия не вышла. Рубеж от этого не опускается: код-пароль знает владелец
    // телефона, и за ним же лежит Keychain, где хранится ключ от всей переписки.
    private func authButtonPressed() {
        let context = LAContext()
        var error: NSError? = nil
        
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
        
            //MARK: Причина видна в системном диалоге, и про Face ID в ней говорить больше
            // нельзя: тем же диалогом вводят код-пароль, когда биометрия не сработала.
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Подтвердите, что это вы") { success, error in
                DispatchQueue.main.async {
                    guard success, error == nil else {
                        //MARK: `error!` здесь был force unwrap в ветке отказа — падение
                        // ровно там, где что-то уже пошло не так. Причина теперь
                        // разбирается, а не печатается в консоль поверх бессодержательного
                        // «Попробуйте снова».
                        if let failure = BiometricFailure.describing(error) {
                            self.showAlert(title: failure.title, message: failure.message)
                        }

                        print("Вход по биометрии не прошёл: \(error?.localizedDescription ?? "причина неизвестна")")

                        return
                    }
                    
                    FirebaseManager.shared.isLogin() ?
                    NotificationCenter.default.post(name: .windowManager, object: nil, userInfo: [String.state: WindowManager.appWindow]) :
                    NotificationCenter.default.post(name: .windowManager, object: nil, userInfo: [String.state: WindowManager.authorizationWindow])
                    
                    print("Biometric authentication success")
                }
            }
        } else {
            //MARK: Сюда попадаем, когда войти нечем вовсе — на телефоне нет ни биометрии,
            // ни код-пароля. Причина по природе та же, поэтому и разбирается тем же
            // способом, а не отдельной веткой с чужим текстом.
            if let failure = BiometricFailure.describing(error) {
                showAlert(title: failure.title, message: failure.message)
            }
        }
    }
}

extension BiometricAuthorizationView {
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let dismissAction = UIAlertAction(title: "Отмена", style: .cancel)
        alert.addAction(dismissAction)
        present(alert, animated: true)
    }
}
