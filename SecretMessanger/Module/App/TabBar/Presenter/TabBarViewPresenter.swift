//
//  TabBarViewPresenter.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 30.01.2025.
//

import Foundation

protocol TabBarViewPresenterProtocol: AnyObject {
    
}

class TabBarViewPresenter: TabBarViewPresenterProtocol {
    
    weak var view: TabBarViewProtocol?
    
    required init(view: any TabBarViewProtocol) {
        self.view = view
        setupControllers()
    }
    
    private func setupControllers() {
//            let messageList = Builder.getMessageListView()
//            messageList.title = "Messages"
//            messageList.tabBarItem.image = UIImage(systemName: "rectangle.3.group.bubble")
//            
//            let userList = Builder.getUserListView()
//            userList.title = "Users"
//            userList.tabBarItem.image = UIImage(systemName: "person.3")
//            
//            let profile = Builder.getProfileView()
//            profile.title = "Profile"
//            profile.tabBarItem.image = UIImage(systemName: "person")
//            
//            view?.setControllers(views: [userList, messageList, profile])
            
        }
}
