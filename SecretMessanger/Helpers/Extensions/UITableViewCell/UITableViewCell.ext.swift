//
//  UITableViewCell.ext.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 12.08.2026.
//

import UIKit

extension UITableViewCell {

    /// Оформляет строку «подпись — значение»: так выглядят оба экрана профиля.
    ///
    /// Подпись серая и мелкая, значение белое и крупнее — читают именно его, подпись лишь
    /// объясняет, что это. Раньше эти восемь строк настройки стояли одинаковыми копиями
    /// в своём и чужом профиле, и разъехаться им мешала только внимательность.
    ///
    /// - Parameters:
    ///   - title: что это за поле — «Логин», «Заметка».
    ///   - value: само значение; пустое остаётся пустым, заглушек здесь нет.
    func configureField(title: String, value: String) {
        backgroundColor = .bgMain
        selectionStyle = .none

        var config = defaultContentConfiguration()

        config.text = title
        config.secondaryText = value
        config.textProperties.color = .inkDim
        config.textProperties.font = .systemFont(ofSize: 14)
        config.secondaryTextProperties.color = .ink
        config.secondaryTextProperties.font = .systemFont(ofSize: 18)

        contentConfiguration = config
    }
}
