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
    
    static func getTabBarView() -> UIViewController {
            let view = TabBarView()
            let presenter = TabBarViewPresenter(view: view)
            
            view.presenter = presenter
            
            return view
        }
    
    static func getUserListView() -> UIViewController {
        let view = UserListView()
        let presenter = UserListViewPresenter(view: view)
        
        view.presenter = presenter
        
        return UINavigationController(rootViewController: view)
    }
    
    static func getMessangerView(chatUser: ChatUser) -> UIViewController {
        let view = MessangerView()
        let presenter = MessangerViewPresenter(view: view, chatUser: chatUser)

        view.presenter = presenter

        return view
    }

    static func getMessageListView() -> UIViewController {
        let view = MessageListView()
        let presenter = MessageListViewPresenter(view: view)
        
        view.presenter = presenter
        
        return UINavigationController(rootViewController: view)
    }
    
    static func getProfileView() -> UIViewController {
        let view = ProfileView()
        let presenter = ProfileViewPresenter(view: view)
        
        view.presenter = presenter
        
        return UINavigationController(rootViewController: view)
    }
    
    static func getProfileViewFromEdit() -> UIViewController {
        let view = ProfileView()
        let presenter = ProfileViewPresenter(view: view)
        
        view.presenter = presenter
        
        return view
    }
    
    static func getUserProfileView() -> UIViewController {
        let view = UserProfileView()
        let presenter = UserProfileViewPresenter(view: view)
        
        view.presenter = presenter
        
        return view
    }
    
    static func getEditProfileView() -> UIViewController {
        let view = EditProfileView()
        let presenter = EditProfileViewPresenter(view: view)
        
        view.presenter = presenter
        
        return view
    }
    
}
