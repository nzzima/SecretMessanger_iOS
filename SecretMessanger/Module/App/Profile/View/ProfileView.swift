//
//  ProfileView.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 30.01.2025.
//

import Foundation
import UIKit

protocol ProfileViewProtocol: AnyObject {
    
}

class ProfileView: UIViewController, ProfileViewProtocol {
    
    var presenter: ProfileViewPresenterProtocol!
    
    let textAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .bgMain
        navigationItem.title = "Профиль"
        navigationController?.navigationBar.titleTextAttributes = textAttributes
    }
}
