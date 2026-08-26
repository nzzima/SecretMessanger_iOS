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
    ///   - mono: моноширинное значение — для того, что читают по знакам, а не словами.
    ///     Такому полю и подпись, и значение достаются приглушёнными: это техническая
    ///     справка, а не то, ради чего экран открывают.
    func configureField(title: String, value: String, mono: Bool = false) {
        backgroundColor = .bgMain
        selectionStyle = .none

        var config = defaultContentConfiguration()

        config.text = title
        config.secondaryText = value
        config.textProperties.color = .inkDim
        config.textProperties.font = .systemFont(ofSize: 14)
        config.secondaryTextProperties.color = mono ? .inkDim : .ink
        config.secondaryTextProperties.font = mono
            ? .monospacedSystemFont(ofSize: 13, weight: .regular)
            : .systemFont(ofSize: 18)

        contentConfiguration = config
    }
}
