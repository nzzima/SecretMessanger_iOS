//
//  VoicePlayer.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 10.08.2026.
//

import Foundation
import AVFoundation
import MessageKit

//MARK: Проигрыватель голосовых. В MessageKit есть ячейка `AudioMessageCell` с кнопкой,
// прогрессом и подписью, но не сам проигрыватель — он живёт в их примере. Этот меньше:
// нам не нужны ни скорость воспроизведения, ни перемотка.
//
// Один на всё приложение намеренно: два голосовых, играющих одновременно, — это не
// возможность, а недосмотр.
final class VoicePlayer: NSObject {

    static let shared = VoicePlayer()

    private var player: AVAudioPlayer?
    private var timer: Timer?
    private weak var cell: AudioMessageCell?

    private(set) var playingMessageId: String?

    private override init() {}

    func toggle(url: URL, messageId: String, cell: AudioMessageCell) {
        if playingMessageId == messageId {
            stop()
            return
        }

        stop()

        do {
            //MARK: Категория переставляется на `.playback`: запись здесь не идёт, а
            // `.playAndRecord` заметно тише и уводит звук в разговорный динамик.
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)

            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.play()

            self.player = player
            self.cell = cell
            self.playingMessageId = messageId

            cell.playButton.isSelected = true
            cell.progressView.progress = 0

            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.tick()
            }
        } catch {
            print("Голосовое не проигрывается: \(error.localizedDescription)")
            reset()
        }
    }

    func stop() {
        player?.stop()
        reset()
    }

    private func tick() {
        guard let player, let cell else { return }

        cell.progressView.progress = Float(player.currentTime / player.duration)
        cell.durationLabel.text = VoicePlayer.formatted(player.duration - player.currentTime)
    }

    private func reset() {
        timer?.invalidate()
        timer = nil

        //MARK: Ячейку возвращаем в исходное сами: она переиспользуется, и оставленный
        // прогресс всплыл бы на чужом сообщении при прокрутке.
        cell?.playButton.isSelected = false
        cell?.progressView.progress = 0

        if let player, let cell {
            cell.durationLabel.text = VoicePlayer.formatted(player.duration)
        }

        cell = nil
        player = nil
        playingMessageId = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    static func formatted(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())

        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

extension VoicePlayer: AVAudioPlayerDelegate {

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        reset()
    }
}
