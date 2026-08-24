//
//  PresenceStore.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 19.08.2026.
//

import Foundation
import FirebaseFirestore

//MARK: Присутствие живёт **отдельной коллекцией**, а не полем в `users/{uid}`, и причина
// та же, по которой отдельно живут аватары: «Контакты» держат слушатель на всю коллекцию
// профилей и перечитывают её при любом изменении любого из них. Удар пульса раз в
// полминуты от каждого человека означал бы перерисовку списка у всех и у каждого — вместе
// с перезаказом аватаров, то есть шторм из ничего.
//
// Вторая причина мельче, но в ту же сторону: правило записи в профиль требует
// `ownsLogin()`, а это `get()` в реестр логинов — лишнее чтение на **каждый** удар.
//
// ```
// presence/{uid}   lastSeen: Timestamp   — серверное время последнего удара
// ```
/// Свой пульс: пока приложение открыто, оно отмечается в `presence/{uid}`.
///
/// Читают чужое присутствие не здесь, а через ``PresenceObserver``.
final class PresenceStore {

    static let shared = PresenceStore()

    private let ref = Firestore.firestore()
    private var timer: Timer?

    //MARK: «Активен» — это не «запущен», а «вошёл и разблокировал». Сессия Firebase живёт
    // месяцами, поэтому на экране Face ID `getUser()` уже возвращает человека — и без
    // этого флага он числился бы в сети, ещё не приложив палец. Для приложения, которое
    // называется секретным, это перебор: присутствие начинается после разблокировки.
    private var isActive = false

    private init() {}

    /// Начать отмечаться: вход выполнен и приложение разблокировано.
    func activate() {
        isActive = true
        beat()
        startTimer()
    }

    /// Перестать отмечаться совсем — выход из аккаунта или блокировка экраном Face ID.
    ///
    /// Последний удар не пишется намеренно: он уже записан, а лишний означал бы «был
    /// в сети», когда человек как раз ушёл.
    func deactivate() {
        isActive = false
        stopTimer()
    }

    /// Приложение вернулось на экран.
    func resume() {
        guard isActive else { return }

        beat()
        startTimer()
    }

    //MARK: Удар на уходе в фон — не формальность: он и есть та отметка, из которой потом
    // вырастает «в сети 20 минут назад». Без него последним следом остался бы случайный
    // удар таймера, до тридцати секунд раньше настоящего ухода.
    /// Приложение ушло в фон: отметиться в последний раз и остановить пульс.
    func pause() {
        stopTimer()

        guard isActive else { return }

        beat()
    }

    private func startTimer() {
        stopTimer()

        //MARK: В фоне таймеры не срабатывают, и это здесь не помеха, а ровно то, что
        // нужно: ушли в фон — пульс сам собой прекращается, а `pause()` ставит финальную
        // отметку.
        timer = Timer.scheduledTimer(withTimeInterval: Presence.heartbeat, repeats: true) { [weak self] _ in
            self?.beat()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    //MARK: Время ставит сервер, а не устройство. Часы на телефоне переводятся руками, и
    // с клиентским временем «в сети» можно было бы себе нарисовать — а правило
    // `lastSeen == request.time` этого просто не пропустит.
    private func beat() {
        guard let uid = FirebaseManager.shared.getUser()?.uid else { return }

        ref.collection(.presence).document(uid).setData([
            "lastSeen": FieldValue.serverTimestamp()
        ]) { err in
            //MARK: Молча. Присутствие — украшение, и падать или тревожить человека
            // из-за не доехавшей точки незачем: следующий удар через полминуты.
            if let err {
                print("Пульс не записался: \(err.localizedDescription)")
            }
        }
    }
}
