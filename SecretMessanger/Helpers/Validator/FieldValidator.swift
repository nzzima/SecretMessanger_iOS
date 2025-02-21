//
//  FieldValidator.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 31.01.2025.
//

import Foundation

class FieldValidator {
    func isValid(_ type: FieldType, _ data: String) -> Bool {
        var dataRegEx = ""
        switch type {
        case .email:
            dataRegEx = "[a-z0-9A-Z._%+-]+@[A-Z0-9a-z.-]+\\.[A-Za-z]{2,64}"
        default:
            dataRegEx = "(?=.*[A-Z0-9a-z]).{6,}"
        }
        
        let dataPred = NSPredicate(format: "SELF MATCHES %@", dataRegEx)
        return dataPred.evaluate(with: data)
    }
}

enum FieldType {
    case login, password, email
}
