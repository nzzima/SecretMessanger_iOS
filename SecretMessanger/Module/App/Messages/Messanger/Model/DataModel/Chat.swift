//
//  Chat.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 07.08.2026.
//

import Foundation
import FirebaseFirestore

//MARK: Всё, что нужно, чтобы открыть переписку — с любым числом участников.
// Ни названия, ни признака группы в базе нет: и то и другое выводится из состава,
// поэтому расходиться с действительностью им негде.
/// Переписка: с кем она и чем шифруется.
///
/// Собирается либо из выбранных контактов (новый чат), либо из документа-шапки
/// `conversation/{id}` — тот инициализатор падающий: диалог, в котором нас нет,
/// показать нечем.
struct Chat {
    let id: String
    let members: [String]
    let logins: [String: String]
    let owner: String
    let selfId: String

    //MARK: Ключ диалога, запечатанный для каждого участника отдельно, и номер его
    // текущей версии — см. ConversationCrypto. Сам ключ отсюда не достать: чтобы
    // открыть свою запись, нужен постоянный ключ из Keychain.
    let convoKeys: [String: String]
    let keyVersion: Int

    //MARK: Докуда каждый дочитал. Метка живёт в шапке, а не в самом сообщении, и это не
    // вкусовщина: на `messages/{id}` стоит `allow update: if false` — сообщение
    // неизменяемо после отправки, и правило это хорошее. Карта в шапке обходится одной
    // записью вместо записи на каждое прочитанное сообщение и заодно сразу показывает,
    // кто в группе докуда добрался.
    let readUpTo: [String: Date]

    var isEncrypted: Bool {
        !convoKeys.isEmpty
    }

    var isGroup: Bool {
        members.count > 2
    }

    //MARK: Создатель — единственный, кто меняет состав. У диалогов, заведённых до
    // появления поля, его нет, и состав в них не поменяет никто: назначать себя
    // создателем задним числом правила не дают, и это осознанно.
    var isOwner: Bool {
        !owner.isEmpty && owner == selfId
    }

    //MARK: Кто вправе стереть переписку целиком. У диалога на двоих это любой из
    // двоих: хозяина у него нет, и ждать, пока сотрёт кто-то один, второму нечего —
    // переписка общая, и уходит она у обоих. Группу стирает только создатель, тот же
    // единственный, кто правит её состав.
    //
    // «Группа» здесь, как и везде в этом типе, выводится из состава, а не из
    // отдельного поля. Отсюда следствие, о котором стоит знать: группа, ужавшаяся до
    // двоих, с этого момента и есть диалог на двоих — стереть её может любой из
    // оставшихся, а не только создатель.
    //
    // Группа, заведённая до появления `owner`, не стирается никем — ровно как и не
    // меняет состав. Назначать себя хозяином задним числом по-прежнему нельзя.
    //
    // Правило то же самое стоит в `firestore.rules`: здесь оно решает, показывать ли
    // свайп, там — пропускать ли запись. Клиентской половины мало, серверной хватает.
    var canErase: Bool {
        isGroup ? isOwner : members.contains(selfId)
    }

    //MARK: Название — логины всех, кроме себя. Для диалога на двоих это просто логин
    // собеседника, так что отдельного правила для группы не требуется.
    var title: String {
        members
            .filter { $0 != selfId }
            .compactMap { logins[$0] }
            .joined(separator: ", ")
    }

    /// Имя участника из кэша в шапке; пустая строка, если мы его ещё не знаем.
    func login(for userId: String) -> String {
        logins[userId] ?? ""
    }

    //MARK: «Прочитано» — значит прочитано **всеми** остальными. В группе на пятерых
    // «прочитали двое» пришлось бы куда-то поместить и как-то читать, а действий из этой
    // цифры не следует никаких: дописывать некому, ждать нечего. Две галочки, когда
    // дошло до последнего, — единственная форма, у которой есть смысл.
    //
    // Сравнение идёт по дате **сообщения**, а не по времени, когда его прочли. Читающий
    // возвращает ту же дату, что стоит в документе, поэтому обе стороны сравнивают числа
    // с одних часов — отправительских. Со временем чтения разошедшиеся часы двух
    // телефонов давали бы то галочки на непрочитанном, то их отсутствие на прочитанном.
    /// Прочитали ли это сообщение все, кроме автора.
    func isRead(_ date: Date, author: String) -> Bool {
        let others = members.filter { $0 != author }

        guard !others.isEmpty else { return false }

        return others.allSatisfy { member in
            guard let seen = readUpTo[member] else { return false }

            return seen >= date
        }
    }
}

extension Chat {

    //MARK: Id диалога на двоих детерминированный — пара uid по алфавиту. Оба
    // собеседника независимо приходят к одному и тому же id, поэтому чат, открытый
    // из контактов, попадает в существующий, а не заводит второй. Для группы состав
    // в id не закодируешь (да и меняться он может), поэтому id случайный, а
    // источником истины о составе служит массив `users` в документе.
    static func conversationId(members: [String]) -> String {
        members.count == 2 ? members.sorted().joined(separator: "_") : UUID().uuidString
    }

    //MARK: Новый чат из выбранных контактов. Создатель — тот, кто выбирал.
    //MARK: Открытые ключи участников сюда больше не едут, и это следствие бага от
    // 24.08.2026. Кэш, принесённый вызывающим, был единственным источником при заведении
    // диалога — а один из двух путей в чат приносил пустоту, и переписка оказывалась
    // запечатана для себя одного. Теперь ключи читает `MessangerManager` прямо из
    // `users`, там они и живут; хранить рядом вторую, отстающую копию незачем.
    init(selfId: String, selfLogin: String, contacts: [ChatUser]) {
        var logins = [selfId: selfLogin]

        contacts.forEach { logins[$0.id] = $0.login }

        let members = [selfId] + contacts.map { $0.id }

        self.id = Chat.conversationId(members: members)
        self.members = members
        self.logins = logins
        self.owner = selfId
        self.selfId = selfId
        self.convoKeys = [:]
        self.keyVersion = 0
        self.readUpTo = [:]
    }

    //MARK: Существующий чат из документа Firestore.
    init?(id: String, selfId: String, data: [String: Any]) {
        guard let members = data["users"] as? [String], members.contains(selfId) else { return nil }

        self.id = id
        self.members = members
        self.logins = data["logins"] as? [String: String] ?? [:]
        self.owner = data["owner"] as? String ?? ""
        self.selfId = selfId
        self.convoKeys = data["convoKeys"] as? [String: String] ?? [:]
        self.keyVersion = data["keyVersion"] as? Int ?? 0

        //MARK: Диалоги, заведённые до появления меток, карты не имеют вовсе — пустая
        // означает «никто ничего не читал», и галочек там просто не будет.
        self.readUpTo = (data["readUpTo"] as? [String: Timestamp] ?? [:]).mapValues { $0.dateValue() }
    }
}
