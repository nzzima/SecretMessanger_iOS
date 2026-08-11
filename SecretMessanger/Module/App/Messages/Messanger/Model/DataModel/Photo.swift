//
//  Photo.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 11.08.2026.
//

import UIKit
import MessageKit

//MARK: Фото в том виде, в каком его показывает MessageKit.
//
// `url` пустой намеренно: у снимка нет адреса в сети, он лежит зашифрованным в
// подколлекции `images`. Байты приезжают отдельно и позже — на момент вёрстки ячейки
// известен только размер, которого для вёрстки и достаточно. Тот же приём, что с
// длительностью у голосовых.
struct Photo: MediaItem {

    var url: URL? { nil }
    var image: UIImage?
    var placeholderImage: UIImage
    var size: CGSize

    init(messageId: String, pixels: CGSize) {
        //MARK: Уже скачанное берём из кэша прямо здесь: ячейка ставит `image` до того,
        // как позовёт делегата, поэтому без этой строки собственное только что
        // отправленное фото мигало бы серым прямоугольником.
        self.image = PhotoCache.shared.image(for: messageId)
        self.placeholderImage = Photo.placeholder
        self.size = Photo.bubble(for: pixels)
    }

    //MARK: Пузырь считается от настоящих пропорций снимка, но с потолком: вертикальное
    // фото иначе занимало бы весь экран, а панорама вырождалась бы в полоску. MessageKit
    // ужмёт ещё раз, если пузырь окажется шире допустимого, — пропорции он сохраняет.
    private static func bubble(for pixels: CGSize) -> CGSize {
        let maxWidth: CGFloat = 240
        let maxHeight: CGFloat = 320

        guard pixels.width > 0, pixels.height > 0 else {
            return CGSize(width: maxWidth, height: maxWidth)
        }

        let scale = min(maxWidth / pixels.width, maxHeight / pixels.height)

        return CGSize(width: (pixels.width * scale).rounded(),
                      height: (pixels.height * scale).rounded())
    }

    //MARK: Заглушка на время загрузки — один тёмный пиксель, который ячейка растянет
    // на весь пузырь. Рисовать в ней иконку незачем: пропорции пузыря уже верные, и
    // серое пятно нужного размера читается как «фото, которое сейчас появится».
    static let placeholder: UIImage = {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        return UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1), format: format).image { context in
            UIColor.darkGray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }()

    //MARK: Фото, которое не расшифровалось, — то же самое, что «🔒 Сообщение не
    // расшифровано» у текста: не сбой загрузки, а переписка, ключ от которой остался на
    // другом устройстве. Молчать об этом нельзя, поэтому у такой ячейки свой вид.
    static let locked: UIImage = {
        let size = CGSize(width: 120, height: 120)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.darkGray.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            guard let lock = UIImage(systemName: "lock.fill")?
                .withTintColor(.lightGray, renderingMode: .alwaysOriginal) else { return }

            let side: CGFloat = 44
            lock.draw(in: CGRect(x: (size.width - side) / 2,
                                 y: (size.height - side) / 2,
                                 width: side,
                                 height: side))
        }
    }()
}
