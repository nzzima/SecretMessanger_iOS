//
//  MessageListViewPresenter.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 31.01.2025.
//

import Foundation

protocol MessageListViewPresenterProtocol: AnyObject {
    
}

class MessageListViewPresenter: MessageListViewPresenterProtocol {
    
    weak var view: MessageListViewProtocol?
    
    required init(view: any MessageListViewProtocol) {
        self.view = view
    }
}
