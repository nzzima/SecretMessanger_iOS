//
//  MessageListView.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 31.01.2025.
//

import Foundation
import UIKit

protocol MessageListViewProtocol: AnyObject {
    
}

class MessageListView: UIViewController, MessageListViewProtocol {
    
    var presenter: MessageListViewPresenterProtocol!
    
    let textAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .bgMain
        navigationItem.title = "Чаты"
        navigationController?.navigationBar.titleTextAttributes = textAttributes
    }
}
