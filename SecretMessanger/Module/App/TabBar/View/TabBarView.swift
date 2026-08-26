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

        //MARK: Фон таб-бара теперь задаёт `BarAppearance` — он один умеет покрасить и
        // прокрученное состояние, из-за которого панель белела. Здесь остаётся цвет
        // выбранной вкладки: это выбор экрана, а не общая подложка.
        //MARK: Оранжевый убран: он был третьим акцентом и спорил с двумя синими за
        // внимание. Акцент в приложении теперь один — вкладки, ссылки, галочки.
        tabBar.tintColor = .accent
    }
    
    func setControllers(views: [UIViewController]) {
        setViewControllers(views, animated: true)
    }
}
