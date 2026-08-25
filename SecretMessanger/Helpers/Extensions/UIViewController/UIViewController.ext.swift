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

    //MARK: Подтверждение действия, у которого есть неочевидная цена. Согласие идёт первой
    // кнопкой и словами о том, что произойдёт, а не «Ок»: из «Ок» не видно, на что
    // соглашаешься.
    //
    //MARK: `destructive` красит согласие красным — не украшение, а системный знак
    // необратимости: им отмечено то, что не отменяется. Разбрасываться им нельзя, иначе
    // он перестанет читаться там, где нужен, — поэтому по умолчанию его нет.
    func showConfirm(title: String,
                     message: String,
                     action: String,
                     destructive: Bool = false,
                     onConfirm: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: action, style: destructive ? .destructive : .default) { _ in
            onConfirm()
        })
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))

        present(alert, animated: true)
    }

    func showAlert(title: String, message: String, onOk: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ок", style: .default) { _ in
            onOk?()
        })
        present(alert, animated: true)
    }
}
