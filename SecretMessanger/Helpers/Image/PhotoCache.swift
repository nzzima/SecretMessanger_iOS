//
//  PhotoCache.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 11.08.2026.
//

import UIKit

//MARK: Расшифрованные фото живут **только в памяти**, и это осознанная разница с
// голосовыми. Звук приходится класть расшифрованным во временную папку: `AVAudioPlayer`
// играет из файла, а не из байтов. Картинке файл не нужен — `UIImage` берётся прямо из
// памяти, так что и расшифрованного снимка на диске не остаётся.
//
// Кэш при этом обязателен, а не «ускорение»: без него открытие чата означало бы
// скачивание всех видимых фото заново при каждой перерисовке ячеек, а перерисовываются
// они на каждое изменение переписки.
final class PhotoCache {

    static let shared = PhotoCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        //MARK: Полсотни снимков — это чуть больше, чем помещается в окно из 50
        // сообщений, на которые подписан чат. Дальше система вычистит сама при нехватке
        // памяти, и фото просто скачается снова.
        cache.countLimit = 60
    }

    func image(for messageId: String) -> UIImage? {
        cache.object(forKey: messageId as NSString)
    }

    func store(_ image: UIImage, for messageId: String) {
        cache.setObject(image, forKey: messageId as NSString)
    }
}
