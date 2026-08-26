//
//  KeyExportView.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 14.08.2026.
//

import Foundation
import UIKit

protocol KeyExportViewProtocol: AnyObject {
    func show(payload: String, qr: UIImage?)
    func showError(_ message: String)
}

//MARK: Экран показывает ключ, а не отправляет его: ни поделиться, ни сохранить в файлы
// отсюда нельзя. Ключ уезжает единственным способом — человек сам считывает QR камерой
// второго устройства или переписывает строку. Кнопка «Поделиться» открыла бы дорогу в
// мессенджеры и облака, то есть ровно туда, куда этот ключ попадать не должен.
/// Перенос ключа на другое устройство: пароль → строка и QR.
final class KeyExportView: UIViewController, KeyExportViewProtocol {

    var presenter: KeyExportViewPresenterProtocol!

    private let explanation: UILabel = {
        $0.text = """
        Ключ открывает всю вашу переписку. Он уедет на второе устройство под паролем, \
        который вы придумаете сейчас, — и этот же пароль спросят там.

        Пароль нигде не хранится. Забудете — перенос придётся делать заново.
        """
        $0.textColor = .inkDim
        $0.font = .systemFont(ofSize: 14)
        $0.numberOfLines = 0
        return $0
    }(UILabel())

    private lazy var passwordField: UITextField = {
        $0.isSecureTextEntry = true
        return $0
    }(TextField(fieldPlaceholder: "Пароль переноса", keyboardType: .asciiCapable))

    private lazy var repeatField: UITextField = {
        $0.isSecureTextEntry = true
        return $0
    }(TextField(fieldPlaceholder: "Ещё раз", keyboardType: .asciiCapable))

    private lazy var exportButton: UIButton = {
        $0.setTitle("Показать ключ", for: .normal)
        $0.setTitleColor(.accent, for: .normal)
        $0.addTarget(self, action: #selector(tappedExport), for: .touchUpInside)
        return $0
    }(UIButton())

    private let qrView: UIImageView = {
        $0.contentMode = .scaleAspectFit
        $0.isHidden = true
        //MARK: Белая подложка обязательна: сканеры ждут тёмный код на светлом, а всё
        // приложение тёмное. Инверсия читается далеко не всякой камерой.
        $0.backgroundColor = .white
        $0.layer.cornerRadius = 12
        return $0
    }(UIImageView())

    private let payloadLabel: UILabel = {
        $0.textColor = .ink
        $0.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        $0.numberOfLines = 0
        $0.textAlignment = .center
        $0.isHidden = true
        return $0
    }(UILabel())

    private lazy var copyButton: UIButton = {
        $0.setTitle("Скопировать строку", for: .normal)
        $0.setTitleColor(.accent, for: .normal)
        $0.isHidden = true
        $0.addTarget(self, action: #selector(tappedCopy), for: .touchUpInside)
        return $0
    }(UIButton())

    private var payload: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .bgMain
        navigationItem.title = "Перенос ключа"
        view.addSubviews(explanation, passwordField, repeatField, exportButton, qrView, payloadLabel, copyButton)

        hideKeyboardWhenTappedAround()
        setConstraints()
    }

    //MARK: Показанный ключ не переживает уход с экрана. Иначе он остался бы висеть в
    // приложении, которое человек оставил открытым и положил на стол.
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        hidePayload()
    }

    @objc private func tappedExport() {
        presenter.export(password: passwordField.text ?? "", repeated: repeatField.text ?? "")
    }

    //MARK: Срок жизни в буфере обмена — минута. Универсального буфера у нас и так нет
    // (`localOnly`), а ключ, лежащий в буфере до перезагрузки, приедет в первое же поле
    // ввода, куда человек нажмёт «вставить».
    @objc private func tappedCopy() {
        guard let payload else { return }

        UIPasteboard.general.setItems(
            [[UIPasteboard.typeAutomatic: payload]],
            options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(60)])

        showAlert(title: "Скопировано", message: "Строка в буфере обмена на минуту")
    }

    func show(payload: String, qr: UIImage?) {
        self.payload = payload
        payloadLabel.text = payload
        qrView.image = qr

        [qrView, payloadLabel, copyButton].forEach { $0.isHidden = false }

        //MARK: Второй раз тот же пароль не спрашиваем, но и поля не оставляем
        // заполненными: экран уже отдал то, за чем на него шли.
        passwordField.text = nil
        repeatField.text = nil
    }

    func showError(_ message: String) {
        showErrorAlert(message)
    }

    private func hidePayload() {
        payload = nil
        payloadLabel.text = nil
        qrView.image = nil
        [qrView, payloadLabel, copyButton].forEach { $0.isHidden = true }
    }

    private func setConstraints() {
        [explanation, passwordField, repeatField, exportButton, qrView, payloadLabel, copyButton]
            .forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            explanation.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            explanation.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            explanation.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            passwordField.topAnchor.constraint(equalTo: explanation.bottomAnchor, constant: 24),
            passwordField.heightAnchor.constraint(equalToConstant: 40),
            passwordField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            passwordField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            repeatField.topAnchor.constraint(equalTo: passwordField.bottomAnchor, constant: 12),
            repeatField.heightAnchor.constraint(equalToConstant: 40),
            repeatField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            repeatField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            exportButton.topAnchor.constraint(equalTo: repeatField.bottomAnchor, constant: 16),
            exportButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            exportButton.heightAnchor.constraint(equalToConstant: 40),

            qrView.topAnchor.constraint(equalTo: exportButton.bottomAnchor, constant: 20),
            qrView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            qrView.widthAnchor.constraint(equalToConstant: 220),
            qrView.heightAnchor.constraint(equalToConstant: 220),

            payloadLabel.topAnchor.constraint(equalTo: qrView.bottomAnchor, constant: 16),
            payloadLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            payloadLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            copyButton.topAnchor.constraint(equalTo: payloadLabel.bottomAnchor, constant: 8),
            copyButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            copyButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
}
