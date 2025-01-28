//
//  AuthorizationView.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 28.01.2025.
//

import UIKit

protocol AuthorizationViewProtocol: AnyObject {
    
}

class AuthorizationView: UIViewController, AuthorizationViewProtocol {
    
    var presenter: AuthorizationViewPresenterProtocol!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
}
