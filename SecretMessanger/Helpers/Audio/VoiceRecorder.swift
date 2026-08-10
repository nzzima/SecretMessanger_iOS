//
//  VoiceRecorder.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 10.08.2026.
//

import Foundation
import AVFoundation

enum VoiceRecorderError: LocalizedError {
    case microphoneDenied
    case failed

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            return "Доступ к микрофону запрещён. Включить его можно в Настройках, в разделе приложения."
        case .failed:
            return "Не удалось начать запись"
        }
    }
}

final class VoiceRecorder: NSObject {

    //MARK: Потолок жёсткий, и держит он не вежливость, а лимит документа Firestore в
    // 1 МиБ. Две минуты в этих настройках — около 360 КБ, треть лимита; запас нужен,
    // потому что упереться в лимит значит потерять уже записанное на отправке.
    static let maxDuration: TimeInterval = 120

    //MARK: Моно и 24 кбит/с — это речь, а не музыка. Ставка здесь ровно на то, что
    // голосовое на порядок меньше фото: только поэтому оно помещается в Firestore и
    // не требует Cloud Storage, а с ним и платного тарифа.
    private let settings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 24_000,
        AVNumberOfChannelsKey: 1,
        AVEncoderBitRateKey: 24_000,
        AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
    ]

    private var recorder: AVAudioRecorder?
    private var url: URL?

    //MARK: Автостоп по потолку приходит сюда — экрану надо убрать своё состояние
    // записи, даже если человек в этот момент никуда не нажимал.
    var onAutoStop: ((URL, TimeInterval) -> Void)?

    var isRecording: Bool { recorder?.isRecording ?? false }

    var currentTime: TimeInterval { recorder?.currentTime ?? 0 }

    func requestPermission(completion: @escaping (Bool) -> Void) {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    func start(completion: @escaping (Error?) -> Void) {
        requestPermission { [weak self] granted in
            guard let self else { return }

            guard granted else {
                completion(VoiceRecorderError.microphoneDenied)
                return
            }

            do {
                //MARK: `.defaultToSpeaker` обязателен: без него `.playAndRecord`
                // отправляет звук в разговорный динамик, и воспроизведение потом
                // еле слышно — телефон будто сломан.
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth])
                try session.setActive(true)

                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("m4a")

                let recorder = try AVAudioRecorder(url: url, settings: self.settings)
                recorder.delegate = self

                guard recorder.record(forDuration: VoiceRecorder.maxDuration) else {
                    completion(VoiceRecorderError.failed)
                    return
                }

                self.recorder = recorder
                self.url = url

                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    //MARK: Длительность снимается ДО остановки: после `stop()` `currentTime`
    // обнуляется, и записанное осталось бы без длины.
    func stop() -> (url: URL, duration: TimeInterval)? {
        guard let recorder, let url else { return nil }

        let duration = recorder.currentTime
        recorder.stop()
        release()

        guard duration >= 1 else {
            //MARK: Меньше секунды — это промах по кнопке, а не сообщение.
            try? FileManager.default.removeItem(at: url)
            return nil
        }

        return (url, duration)
    }

    func cancel() {
        recorder?.stop()

        if let url {
            try? FileManager.default.removeItem(at: url)
        }

        release()
    }

    private func release() {
        recorder = nil
        url = nil

        //MARK: Сессию отпускаем, иначе приложение продолжает держать аудио-маршрут
        // и, например, глушит музыку у человека после единственного голосового.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

extension VoiceRecorder: AVAudioRecorderDelegate {

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        guard flag, let url, isRecordingStoppedByLimit else { return }

        let duration = VoiceRecorder.maxDuration
        release()

        onAutoStop?(url, duration)
    }

    //MARK: Делегат срабатывает и на ручной остановке тоже — там мы уже всё прибрали
    // сами, и повторно звать `onAutoStop` не нужно.
    private var isRecordingStoppedByLimit: Bool { recorder != nil }
}
