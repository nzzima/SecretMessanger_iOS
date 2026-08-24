//
//  PresenceObserver.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 19.08.2026.
//

import Foundation
import FirebaseFirestore

//MARK: Слушателя два вида, и разница между ними — деньги. Экрану профиля и шапке чата
// нужен один человек, и они берут документ. «Контактам» нужны все сразу, и они берут
// коллекцию — сегодня это десятки пользователей и незаметно, на сотнях активных станет
// заметно очень. Тогда коллекция меняется на запрос-окно
// (`whereField("lastSeen", isGreaterThan: сейчас минус минута)`, перезапуск раз в
// полминуты): в ответ приезжают только те, кто в сети, а их всегда меньше, чем всех.
/// Чужое присутствие: одного человека или всех сразу.
///
/// Держать объект должен тот, кто показывает, — презентер. Снимается слушатель сам,
/// когда презентер уходит.
final class PresenceObserver {

    /// За кем следим.
    enum Scope {
        case everyone
        case one(String)
    }

    private let ref = Firestore.firestore()
    private let scope: Scope

    private var listener: ListenerRegistration?
    private var ticker: Timer?

    private var states: [String: Presence] = [:]
    private var handler: (([String: Presence]) -> Void)?

    init(scope: Scope) {
        self.scope = scope
    }

    deinit {
        stop()
    }

    /// Начинает слушать. `handler` зовётся на главной очереди при каждом изменении.
    func start(_ handler: @escaping ([String: Presence]) -> Void) {
        stop()

        self.handler = handler

        switch scope {
        case .everyone:
            listener = ref.collection(.presence).addSnapshotListener { [weak self] snap, err in
                self?.apply(snap?.documents ?? [], error: err)
            }
        case .one(let uid):
            listener = ref.collection(.presence).document(uid).addSnapshotListener { [weak self] snap, err in
                var documents: [DocumentSnapshot] = []

                if let snap, snap.exists { documents = [snap] }

                self?.apply(documents, error: err)
            }
        }

        startTicker()
    }

    /// Снимает слушатель и таймер.
    func stop() {
        listener?.remove()
        listener = nil

        ticker?.invalidate()
        ticker = nil

        handler = nil
    }

    /// В сети ли человек прямо сейчас; про незнакомого — нет.
    func isOnline(_ uid: String) -> Bool {
        states[uid]?.isOnline() ?? false
    }

    /// Присутствие человека, если оно вообще записано.
    func status(of uid: String) -> Presence? {
        states[uid]
    }

    private func apply(_ documents: [DocumentSnapshot], error: Error?) {
        if let error {
            print("Присутствие не загрузилось: \(error.localizedDescription)")
            return
        }

        documents.forEach { doc in
            //MARK: `serverTimestamp()` приезжает пустым в том же снапшоте, которым
            // Firestore отвечает писавшему до подтверждения сервером. Пропускаем: своё
            // присутствие нам всё равно не показывают, а чужое дойдёт следующим
            // снапшотом — уже с настоящим временем.
            guard let stamp = doc.data()?["lastSeen"] as? Timestamp else { return }

            states[doc.documentID] = Presence(lastSeen: stamp.dateValue())
        }

        notify()
    }

    //MARK: Ради этого таймера всё и затевалось. Человек, закрывший приложение, никаких
    // событий больше не порождает — Firestore молчит, и без собственного тика зелёная
    // точка висела бы вечно. Тик пересчитывает то же самое по часам и гасит её сам.
    private func startTicker() {
        ticker?.invalidate()

        ticker = Timer.scheduledTimer(withTimeInterval: Presence.heartbeat, repeats: true) { [weak self] _ in
            self?.notify()
        }
    }

    private func notify() {
        handler?(states)
    }
}
