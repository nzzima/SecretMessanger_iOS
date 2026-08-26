//
//  KeyNoticeCell.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 25.08.2026.
//

import UIKit
import MessageKit

//MARK: Второй и последний знак шифрования в приложении. Первый — замок в шапке
// диалога; больше нигде о шифровании не говорится, и это решение, а не недоделка:
// приложение, без конца напоминающее о своей безопасности, выглядит менее безопасным.
//
//MARK: Это не украшение. Ротация ключа — реальное событие: при удалении участника
// оставшимся выдаётся новый ключ, потому что старый у ушедшего остаётся навсегда. До
// сих пор это происходило молча, и переписка ничем не отличалась от той, где ничего не
// менялось.
/// Отметка «ключ обновлён» в ленте: волосяная линия там, где ключ сменился.
final class KeyNoticeCell: UICollectionViewCell {

    static let reuseIdentifier = "KeyNoticeCell"

    /// Высота строки. Знает и ячейка, и её расчёт размера, поэтому лежит здесь.
    static let height: CGFloat = 34

    private let caption: UILabel = {
        $0.text = "ключ обновлён"
        $0.font = .systemFont(ofSize: 11)
        $0.textColor = .inkDim
        $0.translatesAutoresizingMaskIntoConstraints = false
        return $0
    }(UILabel())

    private static func rule() -> UIView {
        let line = UIView()

        line.backgroundColor = .hairline
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true

        return line
    }

    private let leftRule = KeyNoticeCell.rule()
    private let rightRule = KeyNoticeCell.rule()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.addSubviews(leftRule, caption, rightRule)

        NSLayoutConstraint.activate([
            caption.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            caption.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            leftRule.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            leftRule.trailingAnchor.constraint(equalTo: caption.leadingAnchor, constant: -10),
            leftRule.centerYAnchor.constraint(equalTo: caption.centerYAnchor),

            rightRule.leadingAnchor.constraint(equalTo: caption.trailingAnchor, constant: 10),
            rightRule.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            rightRule.centerYAnchor.constraint(equalTo: caption.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

//MARK: MessageKit считает размеры сам и для `.custom` требует свой расчёт — иначе
// падает с `fatalError`. Ширина приходит снаружи, от коллекции: у отметки нет
// собственного содержимого, от которого её можно было бы вывести.
final class KeyNoticeSizeCalculator: CellSizeCalculator {

    var width: CGFloat = 0

    override func sizeForItem(at indexPath: IndexPath) -> CGSize {
        CGSize(width: width, height: KeyNoticeCell.height)
    }
}
