//
//  AvatarEncoder.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 12.08.2026.
//

import UIKit

//MARK: Подготовка аватара — отдельно от `PhotoEncoder`, хотя приём тот же. Разница в
// том, на что смотрят: снимок в переписке открывают на весь экран, аватар живёт в
// кружке 120 точек, а чаще — в 40. Гнать под него бюджет фотографии значило бы возить
// сотни килобайт ради картинки, которую никто не разглядывает.
//
// Второе отличие — квадрат. Аватар везде показывается в круге с `scaleAspectFill`,
// то есть углы всё равно обрезаются при показе. Резать заранее дешевле: байты за
// невидимые края не платим ни при хранении, ни при каждой загрузке.
enum AvatarEncoder {

    //MARK: 320 точек — это 120-точечный кружок профиля на трёхкратном экране с
    // небольшим запасом. Больше показать негде: всех остальных мест хватает и 120.
    static let side: CGFloat = 320

    //MARK: Потолок с большим запасом: 320×320 в JPEG укладывается в 30–40 КБ, и
    // упереться в него можно разве что шумом во весь кадр. Он тут не ради лимита
    // документа, а чтобы правило Firestore могло проверить размер числом.
    static let budget = 200_000

    private static let qualities: [CGFloat] = [0.8, 0.6, 0.4]

    static func encode(_ image: UIImage) -> Data? {
        let square = squared(image)

        for quality in qualities {
            guard let data = square.jpegData(compressionQuality: quality) else { continue }

            if data.count <= budget {
                return data
            }
        }

        return nil
    }

    //MARK: Обрезка по центру, а не сжатие в квадрат: сплющенное лицо хуже обрезанного.
    // Системный редактор `UIImagePickerController` квадрат уже отдаёт, так что обычно
    // резать нечего — но полагаться на это нельзя, картинка приходит и другими путями.
    private static func squared(_ image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()

        //MARK: Единичный масштаб — чтобы точки совпали с пикселями, иначе на
        // трёхкратном экране renderer молча выдал бы картинку втрое больше
        // запрошенной. Та же ловушка, что в `PhotoEncoder`.
        format.scale = 1
        format.opaque = true

        let target = CGSize(width: side, height: side)

        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            //MARK: Рисуем исходник, увеличенный до перекрытия квадрата, и сдвигаем
            // так, чтобы центр остался в центре. Заодно `draw(in:)` разворачивает
            // картинку по её `orientation` — снятое боком иначе уехало бы набок.
            let scale = max(side / max(image.size.width, 1), side / max(image.size.height, 1))
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let origin = CGPoint(x: (side - size.width) / 2, y: (side - size.height) / 2)

            image.draw(in: CGRect(origin: origin, size: size))
        }
    }
}
