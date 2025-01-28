//
//  Button.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 28.01.2025.
//

import Foundation

import UIKit

class Button: UIButton {
    var buttonText: String
    var completion: () -> Void
    var buttonColor: UIColor
    var titleColor: UIColor
    
    init(buttonText: String, buttonColor: UIColor = .white, titleColor: UIColor = .black, completion: @escaping () -> Void) {
        self.buttonText = buttonText
        self.completion = completion
        self.buttonColor = buttonColor
        self.titleColor = titleColor
        super.init(frame: .zero)
        
        setupButton()
    }
    
    private func setupButton() {
        addAction(UIAction(handler: { [weak self]_ in
            guard let self else { return }
            completion()
        }), for: .touchUpInside)
        
        translatesAutoresizingMaskIntoConstraints = false
        titleLabel?.font = UIFont(name: "Copperplate", size: 16)
        setTitle(buttonText, for: .normal)
        backgroundColor = buttonColor
        setTitleColor(titleColor, for: .normal)
        
        layer.cornerRadius = 14
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
