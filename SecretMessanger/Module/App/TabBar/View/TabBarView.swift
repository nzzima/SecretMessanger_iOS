//
//  TabBarView.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 30.01.2025.
//

import Foundation
import UIKit

protocol TabBarViewProtocol: AnyObject {
    func setControllers(views: [UIViewController])
}

class TabBarView: UITabBarController, TabBarViewProtocol {
    
    var presenter: TabBarViewPresenterProtocol!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func setControllers(views: [UIViewController]) {
        setViewControllers(views, animated: true)
    }
}
