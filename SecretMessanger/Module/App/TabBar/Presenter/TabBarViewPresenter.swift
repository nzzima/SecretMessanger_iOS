//
//  TabBarViewPresenter.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 30.01.2025.
//

import Foundation
import UIKit

protocol TabBarViewPresenterProtocol: AnyObject {
    
}

class TabBarViewPresenter: TabBarViewPresenterProtocol {
    
    weak var view: TabBarViewProtocol?
    
    required init(view: any TabBarViewProtocol) {
        self.view = view
        setupControllers()

        //MARK: Единственная точка, через которую приложение входит в рабочее
        // состояние — после биометрии, после входа и после регистрации. Здесь и
        // проверяем, что открытый ключ этого устройства опубликован.
        IdentityPublisher.publishIfNeeded()
    }
    
    private func setupControllers() {
        let messageList = Builder.getMessageListView()
        messageList.title = "Чаты"
        messageList.tabBarItem.image = UIImage(systemName: "ellipsis.message")
        messageList.tabBarItem.selectedImage = UIImage(systemName: "ellipsis.message.fill")
            
        let userList = Builder.getUserListView()
        userList.title = "Контакты"
        userList.tabBarItem.image = UIImage(systemName: "person.circle")
        userList.tabBarItem.selectedImage = UIImage(systemName: "person.circle.fill")
            
        let profile = Builder.getProfileView()
        profile.title = "Профиль"
        profile.tabBarItem.image = UIImage(systemName: "person")
        profile.tabBarItem.selectedImage = UIImage(systemName: "person.fill")
            
        view?.setControllers(views: [userList, messageList, profile])
            
        }
}
