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
            $0.textColor = .white
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.font = UIFont(name: "Copperplate", size: 36)
            return $0
        }(UILabel())
    
    let pageTitle2: UILabel = {
            $0.text = "заблокирован"
            $0.textColor = .white
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.font = UIFont(name: "Copperplate", size: 36)
            return $0
        }(UILabel())
    
    private lazy var biometricAuthButton:UIButton = Button(buttonText: " Face ID",buttonImage: UIImage(systemName: "faceid") ?? UIImage(), buttonColor: .white, titleColor: .faceid) {
            self.authButtonPressed()
        }
    
    let faceIdImage: UIImageView = {
        $0.image = UIImage(systemName: "faceid")
        $0.tintColor = UIColor.faceid
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
    
    private func authButtonPressed() {
        let context = LAContext()
        var error: NSError? = nil
        
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
        
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Please authenticate with Face ID") { success, error in
                DispatchQueue.main.async {
                    guard success, error == nil else {
                        self.showAlert(title: "Ошибка", message: "Попробуйте снова")
                        print("Biometric authentication failed")
                        print(error!.localizedDescription)
                        return
                    }
                    
                    FirebaseManager.shared.isLogin() ?
                    NotificationCenter.default.post(name: .windowManager, object: nil, userInfo: [String.state: WindowManager.appWindow]) :
                    NotificationCenter.default.post(name: .windowManager, object: nil, userInfo: [String.state: WindowManager.authorizationWindow])
                    
                    print("Biometric authentication success")
                }
            }
        } else {
            if let error {
                showAlert(title: "Нет доступа", message:  "\(error.localizedDescription)")
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
