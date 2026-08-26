//
//  TextField.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 28.01.2025.
//

import UIKit

class TextField: UITextField {
    var fieldPlaceholder: String
    var isPassword: Bool
    var fieldKeyboardType: UIKeyboardType

    init(frame: CGRect = .zero, fieldPlaceholder: String, isPassword: Bool = false, keyboardType: UIKeyboardType = .default) {
        self.fieldPlaceholder = fieldPlaceholder
        self.isPassword = isPassword
        self.fieldKeyboardType = keyboardType

        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        setupTextField()
    }
    
    private func setupTextField() {
        //placeholder = fieldPlaceholder
        attributedPlaceholder = NSAttributedString(string: fieldPlaceholder, attributes: [.foregroundColor: UIColor.inkDim])
        
        isSecureTextEntry = isPassword
        leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 1))
        leftViewMode = .always
        rightView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 1))
        rightViewMode = .always
        //MARK: Поле светлее фона, а не чернее его. Чёрное на тёмно-синем читалось
        // дырой в экране; «поднятое» — это поверхность, на которой пишут.
        backgroundColor = .raised
        textColor = .ink
        layer.cornerRadius = 15
        autocapitalizationType = .none // Disabled field beginning with initial caps
        keyboardAppearance = .dark

        //MARK: Без явного типа клавиатура открывается в языке системы, и в поле почты
        // на русской раскладке набирается кириллица. Для email это ещё и убирает
        // автокоррекцию, которая правит адреса на «похожие» слова.
        keyboardType = fieldKeyboardType

        if fieldKeyboardType == .emailAddress {
            autocorrectionType = .no
            textContentType = .emailAddress
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
