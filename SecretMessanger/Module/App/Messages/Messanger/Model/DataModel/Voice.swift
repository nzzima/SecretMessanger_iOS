//
//  Voice.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 10.08.2026.
//

import Foundation
import MessageKit

//MARK: Голосовое сообщение в том виде, в каком его показывает MessageKit.
//
// `url` здесь — путь в кэше, а не адрес в сети, и на момент отрисовки файла по нему
// обычно ещё нет. Так и задумано: ячейке для вёрстки нужна только длительность, а
// байты стоит тащить из базы лишь тогда, когда человек нажал «играть». Иначе открытие
// чата с десятком голосовых означало бы десяток скачиваний, из которых послушают одно.
struct Voice: AudioItem {

    var url: URL
    var duration: Float
    var size: CGSize

    init(messageId: String, duration: Float) {
        self.url = Voice.cacheURL(messageId: messageId)
        self.duration = duration
        self.size = CGSize(width: 200, height: 40)
    }

    //MARK: Расшифрованный звук ложится во временную папку приложения — иначе его
    // нечем отдать `AVAudioPlayer`, он умеет играть из файла. Песочница приложения
    // чужому доступу закрыта, но факт остаётся: на диске звук лежит открытым, и
    // система вправе вычистить папку когда угодно — тогда файл просто скачается снова.
    static func cacheURL(messageId: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-" + messageId)
            .appendingPathExtension("m4a")
    }

    static func isCached(messageId: String) -> Bool {
        FileManager.default.fileExists(atPath: cacheURL(messageId: messageId).path)
    }
}
