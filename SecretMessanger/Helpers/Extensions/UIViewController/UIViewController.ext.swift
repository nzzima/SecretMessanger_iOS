//
//  UIViewController.ext.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 29.01.2025.
//

import Foundation
import UIKit

extension UIViewController {
    func hideKeyboardWhenTappedAround() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

    func showErrorAlert(_ message: String) {
        showAlert(title: "Ошибка", message: message)
    }

    func showAlert(title: String, message: String, onOk: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ок", style: .default) { _ in
            onOk?()
        })
        present(alert, animated: true)
    }
}
