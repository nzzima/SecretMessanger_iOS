//
//  AvatarImageView.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 12.08.2026.
//

import UIKit

/// Круглая картинка человека — одна на все места, где он показывается.
///
/// До появления этого типа аватар жил пятью копиями: три экрана профиля повторяли
/// одну и ту же настройку кружка с обводкой, а две ячейки списков — один и тот же
/// порядок загрузки (кэш → заглушка → запрос → сверка, что ячейку не переиспользовали).
/// Копии успели разойтись в мелочах, и каждая новая точка показа расходилась бы дальше.
///
/// Кто грузит картинку, зависит от места:
/// - экраны профиля получают готовое изображение от презентера — ``show(_:)``;
/// - ячейки списков просят её сами по uid и версии — ``load(uid:version:)``.
///
/// ```swift
/// // Профиль: 120 pt с обводкой, картинку приносит презентер
/// let avatar = AvatarImageView.profile()
/// avatar.show(presenter.avatar)
///
/// // Ячейка списка: 60 pt, картинку ищет сама
/// avatarView.load(uid: user.id, version: user.avatarVersion)
/// ```
final class AvatarImageView: UIImageView {

    /// Диаметр кружка на экранах профиля, в точках.
    static let profileDiameter: CGFloat = 120

    /// Диаметр кружка в строке списка, в точках.
    static let cellDiameter: CGFloat = 60

    /// Чей аватар кружок ждёт прямо сейчас.
    ///
    /// Ячейки переиспользуются, и пока картинка едет, та же ячейка успевает уехать под
    /// другого человека. Без этой сверки в списках появлялись бы чужие лица.
    private var awaitedUid: String?

    /// Диаметр кружка. Хранится потому, что размер символа группы считается от него:
    /// на момент настройки ячейки `bounds` ещё нулевой, вёрстка не прошла.
    private var diameter: CGFloat = AvatarImageView.cellDiameter

    /// Кружок для экрана профиля: 120 pt и серая обводка.
    static func profile() -> AvatarImageView {
        make(diameter: profileDiameter, borderWidth: 4)
    }

    /// Кружок для строки списка: 60 pt, без обводки.
    static func cell() -> AvatarImageView {
        make(diameter: cellDiameter, borderWidth: 0)
    }

    private static func make(diameter: CGFloat, borderWidth: CGFloat) -> AvatarImageView {
        let view = AvatarImageView()

        view.diameter = diameter
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.masksToBounds = true
        view.layer.cornerRadius = diameter / 2
        view.layer.borderWidth = borderWidth
        view.layer.borderColor = UIColor.gray.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false

        view.showPlaceholder()

        return view
    }

    /// Показывает готовую картинку; `nil` — общая заглушка.
    ///
    /// Для экранов профиля, где аватар грузит презентер: он же слушает профиль и знает,
    /// сменилась ли версия.
    func show(_ image: UIImage?) {
        awaitedUid = nil

        guard let image else {
            showPlaceholder()
            return
        }

        display(image)
    }

    /// Ищет и показывает аватар человека; пока его нет — заглушка.
    ///
    /// Для ячеек списков. Кэш спрашивается синхронно: у большинства строк картинка уже
    /// есть, и асинхронный заказ ради неё моргал бы заглушкой на каждой прокрутке.
    ///
    /// - Parameters:
    ///   - uid: чей аватар нужен.
    ///   - version: версия из профиля; ноль означает «аватара нет», и запроса не будет.
    func load(uid: String, version: Int) {
        awaitedUid = uid

        if let cached = AvatarStore.shared.cached(uid: uid, version: version) {
            display(cached)
            return
        }

        showPlaceholder()

        AvatarStore.shared.load(uid: uid, version: version) { [weak self] image in
            guard let self, let image, self.awaitedUid == uid else { return }

            self.display(image)
        }
    }

    /// Показывает значок группы вместо лица.
    ///
    /// У группы собеседник не один, и ставить фотографию кого-то одного из участников
    /// значило бы врать. Значок заодно отличает группу от диалога с одного взгляда.
    func showGroup() {
        awaitedUid = nil

        //MARK: Символ рисуется по центру, а не растягивается: у `person.2.fill` свои
        // поля, и `scaleAspectFill` расплющил бы его о края кружка.
        image = UIImage(systemName: "person.2.fill",
                        withConfiguration: UIImage.SymbolConfiguration(pointSize: diameter / 2.3))
        contentMode = .center
        tintColor = .lightGray
        backgroundColor = .black
    }

    /// Общая заглушка — человек без фотографии.
    func showPlaceholder() {
        image = UIImage(named: "basicUserImage")
        contentMode = .scaleAspectFill
        backgroundColor = .clear
    }

    private func display(_ image: UIImage) {
        self.image = image
        contentMode = .scaleAspectFill
        backgroundColor = .clear
    }
}
