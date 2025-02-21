//
//  UserProfileView.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 21.02.2025.
//

import Foundation
import UIKit

protocol UserProfileViewProtocol: AnyObject {
    
}

class UserProfileView: UIViewController, UserProfileViewProtocol {
    
    var presenter: UserProfileViewPresenterProtocol!
    
    let textAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .bgMain
        navigationItem.title = "User login"
        navigationController?.navigationBar.titleTextAttributes = textAttributes
    }
    
}
