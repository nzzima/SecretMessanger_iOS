//
//  Presence.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 19.08.2026.
//

import Foundation

//MARK: В базе лежит **одно** поле — время последнего удара пульса. Флага `online: Bool`
// здесь намеренно нет: приложение, снятое из переключателя задач, дописать «я ушёл» уже
// не успеет, и такой флаг застрял бы на «в сети» навсегда — то есть врал бы, и врал бы
// молча, до следующего запуска. Вычисляемое присутствие врать не умеет вовсе: пульс
// прекратился — человек гаснет сам, без чьей-либо помощи.
/// Присутствие человека: когда его видели в последний раз.
///
/// Тип чистый — ни Firestore, ни UIKit. Всё, что он делает, проверяется тестами
/// (`PresenceTests`), потому что «в сети» и «в сети вчера в 21:14» — это арифметика по
/// двум датам, и ошибаться в ней на глаз не хочется.
struct Presence {

    /// Как часто приложение отмечается, пока оно на экране.
    static let heartbeat: TimeInterval = 30

    //MARK: Больше двух ударов пульса, а не одного. Пропущенный удар — обычное дело в
    // метро, в лифте и на плохом Wi-Fi, и с окном в один удар собеседник мигал бы серым
    // на ровном месте. Плата за запас честная: тот, кто закрыл приложение, ещё чуть
    // больше минуты числится сетевым.
    /// Сколько времени после последнего удара человек ещё считается сетевым.
    static let onlineWindow: TimeInterval = 70

    /// Время последнего удара пульса — серверное, а не с часов писавшего.
    let lastSeen: Date

    /// В сети ли человек прямо сейчас.
    ///
    /// - Note: `now` берётся с часов **читающего**, а `lastSeen` — с сервера. Разошедшиеся
    ///   часы читателя сдвинут ответ на всю величину расхождения, и сделать с этим
    ///   ничего нельзя: спрашивать у сервера время на каждую перерисовку дороже, чем
    ///   стоит сама точка.
    func isOnline(now: Date = Date()) -> Bool {
        //MARK: Разница выходит отрицательной, когда часы читателя отстают от серверных.
        // Сравнение «меньше окна» такой случай проглатывает само и считает человека
        // сетевым — это верно по смыслу: удар пульса пришёл, просто по нашим часам он
        // «из будущего».
        return now.timeIntervalSince(lastSeen) < Presence.onlineWindow
    }

    //MARK: Без рода. «Был» и «была» требуют знать пол, которого в профиле нет и не
    // предвидится, а «был(а) в сети» — это канцелярия в приложении для переписки.
    // «В сети 5 минут назад» говорит ровно то же и ни о ком не врёт.
    /// Подпись под именем: «в сети» либо когда человека видели в последний раз.
    ///
    /// - Parameters:
    ///   - now: текущий момент; параметр ради тестов.
    ///   - calendar: календарь читателя — из него берётся и часовой пояс.
    func text(now: Date = Date(), calendar: Calendar = .current) -> String {
        if isOnline(now: now) { return "в сети" }

        let elapsed = now.timeIntervalSince(lastSeen)

        //MARK: Внутри часа человеку интереснее «сколько прошло», а не «в котором часу»:
        // «в сети 20 минут назад» читается сразу, «в сети сегодня в 14:32» требует
        // посмотреть на свои часы и вычесть.
        if elapsed < 3600 {
            let minutes = max(1, Int(elapsed / 60))

            return "в сети \(minutes) \(Presence.minutesWord(minutes)) назад"
        }

        //MARK: «Сегодня» и «вчера» считаются от переданного `now`, а не от системных
        // часов: `isDateInToday` смотрит на настоящее сейчас, и с ним подпись зависела бы
        // от двух источников времени сразу — а тесты, подставляющие свой момент, ловили бы
        // сегодняшнюю дату машины.
        if calendar.isDate(lastSeen, inSameDayAs: now) {
            return "в сети сегодня в \(Presence.time(lastSeen, calendar))"
        }

        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(lastSeen, inSameDayAs: yesterday) {
            return "в сети вчера в \(Presence.time(lastSeen, calendar))"
        }

        return "в сети \(Presence.day(lastSeen, calendar))"
    }

    //MARK: Русский счёт: 1 минуту, 2 минуты, 5 минут — и отдельно вторая дюжина, где
    // 11 и 12 ведут себя не как 1 и 2.
    private static func minutesWord(_ count: Int) -> String {
        if (11...14).contains(count % 100) { return "минут" }

        switch count % 10 {
        case 1: return "минуту"
        case 2...4: return "минуты"
        default: return "минут"
        }
    }

    //MARK: Форматтеры общие, а не по одному на вызов: создание `DateFormatter` стоит
    // заметно дороже самого форматирования. Трогаются они только с главной очереди —
    // подпись рисуется в шапке чата и в профиле, а `DateFormatter` не потокобезопасен.
    private static let timeFormatter: DateFormatter = {
        $0.locale = Locale(identifier: "ru_RU")
        $0.dateFormat = "HH:mm"
        return $0
    }(DateFormatter())

    private static let dayFormatter: DateFormatter = {
        $0.locale = Locale(identifier: "ru_RU")
        $0.dateFormat = "d MMMM"
        return $0
    }(DateFormatter())

    private static func time(_ date: Date, _ calendar: Calendar) -> String {
        timeFormatter.timeZone = calendar.timeZone

        return timeFormatter.string(from: date)
    }

    private static func day(_ date: Date, _ calendar: Calendar) -> String {
        dayFormatter.timeZone = calendar.timeZone

        return dayFormatter.string(from: date)
    }
}
