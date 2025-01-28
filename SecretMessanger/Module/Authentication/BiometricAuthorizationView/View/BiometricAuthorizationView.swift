//
//  BiometricAuthorizationView.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 28.01.2025.
//

import UIKit

protocol BiometricAuthorizationViewProtocol: AnyObject {
    
}

class BiometricAuthorizationView: UIViewController, BiometricAuthorizationViewProtocol {
    
    var presenter: BiometricAuthorizationViewPresenterProtocol!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .blue
    }
}
