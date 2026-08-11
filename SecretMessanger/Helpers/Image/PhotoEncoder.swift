//
//  PhotoEncoder.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 11.08.2026.
//

import UIKit

enum PhotoEncoderError: LocalizedError {
    case tooLarge

    var errorDescription: String? {
        switch self {
        case .tooLarge:
            return "Это фото не удалось уместить в размер сообщения"
        }
    }
}

//MARK: Подготовка фото к отправке — и весь смысл этого файла в том, чтобы снимок
// поместился **в документ Firestore**. Cloud Storage потребовал бы Blaze, а вместе с
// ним и вторую систему правил, которая не умеет читать Firestore и потому не может
// проверить участие в диалоге. Голосовые эту развилку уже прошли: байты лежат в базе.
//
// Разница с голосовыми в том, что длину записи держит рекордер, а размер снимка — никто:
// с камеры приезжают 12 мегапикселей и 4 МБ, то есть вчетверо больше лимита документа.
// Поэтому фото не «сжимается на всякий случай», а именно подгоняется под бюджет.
enum PhotoEncoder {

    //MARK: Бюджет с запасом от лимита в 1 МиБ. Сверху лягут 28 байт AES-GCM, имена
    // полей, id документа и накладные протокола — считать их поштучно незачем, дешевле
    // оставить четверть лимита свободной. Упереться в предел на отправке значило бы
    // потерять уже выбранное фото, ровно как у потолка длительности записи.
    static let budget = 700_000

    //MARK: 1280 по длинной стороне: фото смотрят с телефона, где даже на полный экран
    // ретина просит около 1200 точек. Больше — это байты, которых никто не увидит.
    static let maxSide: CGFloat = 1280

    //MARK: Сначала жертвуем качеством, и только потом — размером. Замыленные 1280
    // читаются лучше, чем резкие 640: на фото обычно важно, что на нём, а не
    // попиксельная чистота. Планка 0.35 — граница, за которой JPEG идёт квадратами.
    private static let qualities: [CGFloat] = [0.7, 0.5, 0.35]

    //MARK: Возвращает и байты, и размер получившейся картинки: размер уезжает в
    // документ сообщения, чтобы ячейку можно было сверстать до того, как приедут сами
    // байты. Тот же приём, что с длительностью у голосовых.
    static func encode(_ image: UIImage) -> (data: Data, size: CGSize)? {
        var side = maxSide

        //MARK: Три захода с делением стороны пополам покрывают всё, что может отдать
        // камера: даже панорама на 50 мегапикселей к третьему заходу укладывается.
        for _ in 0..<3 {
            let scaled = resized(image, maxSide: side)

            for quality in qualities {
                guard let data = scaled.jpegData(compressionQuality: quality) else { continue }

                if data.count <= budget {
                    return (data, scaled.size)
                }
            }

            side /= 2
        }

        return nil
    }

    //MARK: Рисование через renderer заодно разворачивает картинку по её `orientation`:
    // снятое боком фото хранит пиксели в исходной ориентации и флаг поворота, а флаг
    // при перекодировании в JPEG теряется — без этого шага снимки уезжали бы набок.
    private static func resized(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)

        //MARK: Маленькое фото не растягиваем: увеличение добавляет байты и не добавляет
        // ни одной новой детали.
        let scale = min(1, maxSide / max(longest, 1))
        let target = CGSize(width: (image.size.width * scale).rounded(),
                            height: (image.size.height * scale).rounded())

        let format = UIGraphicsImageRendererFormat.default()

        //MARK: Единичный масштаб — чтобы точки совпали с пикселями. Иначе на трёхкратном
        // экране renderer молча выдал бы картинку втрое больше запрошенной, и весь расчёт
        // бюджета поехал бы.
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
