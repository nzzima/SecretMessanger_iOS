//
//  ReadReceiptTests.swift
//  SecretMessangerTests
//
//  Created by Nikita Krylov on 24.08.2026.
//

import XCTest
import FirebaseFirestore
@testable import SecretMessanger

/// Кто и докуда дочитал — арифметика по карте `readUpTo` и дате сообщения. Ошибка здесь
/// не роняет ничего и потому особенно неприятна: две галочки у того, кто сообщения не
/// открывал, заставляют ждать ответа, которого не будет.
final class ReadReceiptTests: XCTestCase {

    private let me = "me"
    private let them = "them"

    private func date(_ minute: Int) -> Date {
        Date(timeIntervalSince1970: 1_700_000_000 + Double(minute) * 60)
    }

    private func chat(members: [String], readUpTo: [String: Date]) -> Chat {
        var data: [String: Any] = ["users": members]

        if !readUpTo.isEmpty {
            data["readUpTo"] = readUpTo.mapValues { Timestamp(date: $0) }
        }

        return Chat(id: "convo", selfId: me, data: data)!
    }

    // MARK: - Диалог на двоих

    func testUnreadWhileCompanionHasNotCaughtUp() {
        let chat = chat(members: [me, them], readUpTo: [them: date(5)])

        XCTAssertFalse(chat.isRead(date(7), author: me))
    }

    func testReadOnceCompanionPassedTheMessage() {
        let chat = chat(members: [me, them], readUpTo: [them: date(9)])

        XCTAssertTrue(chat.isRead(date(7), author: me))
    }

    /// Дочитал ровно до этого сообщения — значит прочитал и его. Строгое сравнение здесь
    /// оставляло бы последнее сообщение вечно непрочитанным.
    func testExactlyUpToCountsAsRead() {
        let chat = chat(members: [me, them], readUpTo: [them: date(7)])

        XCTAssertTrue(chat.isRead(date(7), author: me))
    }

    /// Диалог, заведённый до появления меток, карты не имеет вовсе.
    func testNoReceiptsMeansUnread() {
        let chat = chat(members: [me, them], readUpTo: [:])

        XCTAssertFalse(chat.isRead(date(1), author: me))
    }

    /// Своя отметка на свои же сообщения не влияет: читателем считается кто угодно,
    /// кроме автора.
    func testOwnReceiptDoesNotMarkOwnMessage() {
        let chat = chat(members: [me, them], readUpTo: [me: date(99)])

        XCTAssertFalse(chat.isRead(date(1), author: me))
    }

    // MARK: - Группа

    func testGroupNeedsEveryone() {
        let third = "third"
        let chat = chat(members: [me, them, third], readUpTo: [them: date(9)])

        XCTAssertFalse(chat.isRead(date(7), author: me), "Один прочитал — это ещё не «прочитано»")
    }

    func testGroupReadWhenAllCaughtUp() {
        let third = "third"
        let chat = chat(members: [me, them, third],
                        readUpTo: [them: date(9), third: date(8)])

        XCTAssertTrue(chat.isRead(date(7), author: me))
    }

    /// Отставший держит галочки выключенными, сколько бы человек ни прочитало до него.
    func testGroupOneLaggardKeepsItUnread() {
        let third = "third"
        let chat = chat(members: [me, them, third],
                        readUpTo: [them: date(9), third: date(3)])

        XCTAssertFalse(chat.isRead(date(7), author: me))
    }

    // MARK: - Точность дат

    //MARK: Из-за этого галочка не синела, и поймать это удалось только логом с шестью
    // знаками после запятой: в секундах обе величины выглядят одинаково.
    /// Отметка, пересобранная из `Date`, промахивается мимо своего же сообщения.
    ///
    /// `Timestamp` хранит наносекунды, `Date` — `Double`, и на масштабе 1.8 млрд секунд
    /// разрядов под наносекунды не остаётся. Обратный перевод уезжает вниз — на живом
    /// диалоге промах составил 9.5e-07 секунды, — и «дочитал ровно до этого сообщения»
    /// превращается в «не дочитал» навсегда: новых сообщений нет, метка больше не
    /// обновится.
    func testReceiptRebuiltFromDateMissesItsOwnMessage() {
        let stored = Timestamp(seconds: 1_787_570_025, nanoseconds: 637_431_000)
        let messageDate = stored.dateValue()

        let rebuilt = Timestamp(date: messageDate).dateValue()
        let chat = chat(members: [me, them], readUpTo: [them: rebuilt])

        //MARK: Тест не утверждает, что промах есть **всегда** — он зависит от значения.
        // Утверждается ровно то, ради чего он написан: если промах случился, галочки
        // гаснут, и полагаться на пересобранную дату нельзя.
        if rebuilt < messageDate {
            XCTAssertFalse(chat.isRead(messageDate, author: me),
                           "Пересобранная дата отстала — галочек не будет")
        }
    }

    /// А отметка, вернувшаяся тем же `Timestamp`, что лежит в документе, совпадает точно.
    /// Ради этого `Message` и хранит исходный `Timestamp`, а не только его `Date`.
    func testReceiptEchoedAsStoredTimestampMatchesExactly() {
        let stored = Timestamp(seconds: 1_787_570_025, nanoseconds: 637_431_000)
        let chat = chat(members: [me, them], readUpTo: [them: stored.dateValue()])

        XCTAssertTrue(chat.isRead(stored.dateValue(), author: me))
    }

    // MARK: - Вырожденный случай

    /// Диалог с самим собой читателей не имеет, и галочек в нём быть не может —
    /// `allSatisfy` на пустом множестве иначе вернул бы `true` и зажёг их всегда.
    func testChatWithoutOthersIsNeverRead() {
        let chat = chat(members: [me], readUpTo: [me: date(99)])

        XCTAssertFalse(chat.isRead(date(1), author: me))
    }
}
