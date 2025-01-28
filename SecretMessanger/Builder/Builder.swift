//
//  Builder.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 28.01.2025.
//

import UIKit

class Builder {
    static func getAuthorizationView() -> UIViewController {
        let view = AuthorizationView()
        let presenter = AuthorizationViewPresenter(view: view)
        
        view.presenter = presenter
        
        return view
    }
    
    static func getBiometricAuthorizationView() -> UIViewController {
        let view = BiometricAuthorizationView()
        let presenter = BiometricAuthorizationViewPresenter(view: view)
        
        view.presenter = presenter
        
        return view
    }
}
