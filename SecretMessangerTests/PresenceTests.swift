//
//  PresenceTests.swift
//  SecretMessangerTests
//
//  Created by Nikita Krylov on 19.08.2026.
//

import XCTest
@testable import SecretMessanger

/// Присутствие — это арифметика по двум датам, и ошибиться в ней на глаз легко: окно
/// «в сети», граница часа, вчера против позавчера и русский счёт минут. Всё, что тут
/// проверяется, руками на телефоне не проверишь — пришлось бы ждать сутки.
final class PresenceTests: XCTestCase {

    //MARK: Календарь и часовой пояс задаются явно. С системными тест зеленел бы в
    // Москве и краснел в другом поясе — а падать он должен от кода, а не от места.
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow")!
        return calendar
    }()

    private func date(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        return formatter.date(from: string)!
    }

    // MARK: - Окно «в сети»

    func testFreshBeatIsOnline() {
        let now = date("2026-08-19 14:00:00")
        let presence = Presence(lastSeen: now.addingTimeInterval(-10))

        XCTAssertTrue(presence.isOnline(now: now))
        XCTAssertEqual(presence.text(now: now, calendar: calendar), "в сети")
    }

    /// Пропущенный удар пульса не гасит человека: окно шире двух ударов намеренно.
    func testOneMissedBeatStaysOnline() {
        let now = date("2026-08-19 14:00:00")
        let presence = Presence(lastSeen: now.addingTimeInterval(-Presence.heartbeat - 5))

        XCTAssertTrue(presence.isOnline(now: now))
    }

    func testBeyondWindowGoesOffline() {
        let now = date("2026-08-19 14:00:00")
        let presence = Presence(lastSeen: now.addingTimeInterval(-Presence.onlineWindow - 1))

        XCTAssertFalse(presence.isOnline(now: now))
    }

    /// Часы читателя отстают от серверных — отметка приходит «из будущего». Это «только
    /// что», а не «никогда».
    func testBeatFromTheFutureCountsAsOnline() {
        let now = date("2026-08-19 14:00:00")
        let presence = Presence(lastSeen: now.addingTimeInterval(30))

        XCTAssertTrue(presence.isOnline(now: now))
    }

    // MARK: - Русский счёт минут

    func testMinutesAreSpelledByRussianRules() {
        let now = date("2026-08-19 14:00:00")

        func text(minutesAgo: Int) -> String {
            Presence(lastSeen: now.addingTimeInterval(-Double(minutesAgo) * 60))
                .text(now: now, calendar: calendar)
        }

        XCTAssertEqual(text(minutesAgo: 2), "в сети 2 минуты назад")
        XCTAssertEqual(text(minutesAgo: 5), "в сети 5 минут назад")
        XCTAssertEqual(text(minutesAgo: 11), "в сети 11 минут назад")
        XCTAssertEqual(text(minutesAgo: 21), "в сети 21 минуту назад")
        XCTAssertEqual(text(minutesAgo: 22), "в сети 22 минуты назад")
        XCTAssertEqual(text(minutesAgo: 25), "в сети 25 минут назад")
    }

    /// Между концом окна «в сети» и первой полной минутой — дыра в пятьдесят секунд.
    /// Без нижней границы там печаталось бы «в сети 0 минут назад».
    func testJustOffTheWindowShowsOneMinute() {
        let now = date("2026-08-19 14:00:00")
        let presence = Presence(lastSeen: now.addingTimeInterval(-Presence.onlineWindow - 1))

        XCTAssertEqual(presence.text(now: now, calendar: calendar), "в сети 1 минуту назад")
    }

    // MARK: - Часы, дни и границы суток

    /// Ровно час — уже не «минуты назад»: дальше время дня читается легче, чем счёт.
    func testAfterAnHourSwitchesToClockTime() {
        let now = date("2026-08-19 14:00:00")
        let presence = Presence(lastSeen: date("2026-08-19 12:32:00"))

        XCTAssertEqual(presence.text(now: now, calendar: calendar), "в сети сегодня в 12:32")
    }

    func testYesterdayIsNamedYesterday() {
        let now = date("2026-08-19 09:00:00")
        let presence = Presence(lastSeen: date("2026-08-18 21:14:00"))

        XCTAssertEqual(presence.text(now: now, calendar: calendar), "в сети вчера в 21:14")
    }

    /// Полночь — граница «вчера», а не двадцать четыре часа назад: отметка в 23:50
    /// становится вчерашней уже к трём часам ночи, а не к следующему вечеру.
    func testMidnightMakesItYesterday() {
        let now = date("2026-08-19 02:10:00")
        let presence = Presence(lastSeen: date("2026-08-18 23:50:00"))

        XCTAssertEqual(presence.text(now: now, calendar: calendar), "в сети вчера в 23:50")
    }

    /// А внутри часа полночь ничего не меняет: «20 минут назад» понятнее, чем «вчера
    /// в 23:50», даже когда сутки успели смениться.
    func testWithinAnHourMidnightChangesNothing() {
        let now = date("2026-08-19 00:10:00")
        let presence = Presence(lastSeen: date("2026-08-18 23:50:00"))

        XCTAssertEqual(presence.text(now: now, calendar: calendar), "в сети 20 минут назад")
    }

    func testOlderThanYesterdayShowsTheDate() {
        let now = date("2026-08-19 14:00:00")
        let presence = Presence(lastSeen: date("2026-08-12 10:05:00"))

        XCTAssertEqual(presence.text(now: now, calendar: calendar), "в сети 12 августа")
    }

    // MARK: - Что подпись не говорит

    /// Ни в одном ответе нет ни «был», ни «была», ни «был(а)»: пола в профиле нет, а
    /// угадывать его подписью — худшее из решений.
    func testTextNeverGuessesGender() {
        let now = date("2026-08-19 14:00:00")
        let moments = [10.0, 200, 4000, 100_000, 900_000].map { now.addingTimeInterval(-$0) }

        moments.forEach { moment in
            let text = Presence(lastSeen: moment).text(now: now, calendar: calendar)

            XCTAssertFalse(text.contains("был"), "Подпись «\(text)» угадывает пол")
        }
    }
}
