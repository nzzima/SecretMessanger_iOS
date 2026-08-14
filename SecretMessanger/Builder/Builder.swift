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
    
    static func getRegistrationView() -> UIViewController {
        let view = RegistrationView()
        let presenter = RegistrationViewPresenter(view: view)

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
    
    static func getMessangerView(chat: Chat) -> UIViewController {
        let view = MessangerView()
        let presenter = MessangerViewPresenter(view: view, chat: chat)

        view.presenter = presenter

        return view
    }

    static func getNewChatView() -> UIViewController {
        let view = NewChatView()
        let presenter = NewChatViewPresenter(view: view)

        view.presenter = presenter

        return view
    }

    static func getAddMembersView(excluded: Set<String>, onAdd: @escaping ([ChatUser]) -> Void) -> UIViewController {
        let view = NewChatView()
        let presenter = NewChatViewPresenter(view: view, mode: .addMembers(excluded: excluded, onAdd: onAdd))

        view.presenter = presenter

        return view
    }

    static func getChatMembersView(chat: Chat) -> UIViewController {
        let view = ChatMembersView()
        let presenter = ChatMembersViewPresenter(view: view, chat: chat)

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
    
    static func getUserProfileView(chatUser: ChatUser) -> UIViewController {
        let view = UserProfileView()
        let presenter = UserProfileViewPresenter(view: view, chatUser: chatUser)

        view.presenter = presenter

        return view
    }
    
    static func getEditProfileView() -> UIViewController {
        let view = EditProfileView()
        let presenter = EditProfileViewPresenter(view: view)

        view.presenter = presenter

        return view
    }

    static func getKeyExportView() -> UIViewController {
        let view = KeyExportView()
        let presenter = KeyExportViewPresenter(view: view)

        view.presenter = presenter

        return view
    }
    
}
