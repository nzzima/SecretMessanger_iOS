//
//  ChatDeletionTests.swift
//  SecretMessangerTests
//
//  Created by Nikita Krylov on 25.08.2026.
//

import XCTest
@testable import SecretMessanger

/// Кому диалог даёт себя стереть.
///
/// Удаление здесь необратимо и общее: переписка уходит у всех участников сразу, а не
/// прячется у одного. Ошибка в этом решении стоит чужой истории, поэтому оно живёт в
/// модели, считается без сети и проверяется здесь.
///
/// То же самое правило слово в слово стоит в `firestore.rules` — эта половина решает,
/// показывать ли свайп, та решает, пропускать ли запись. Разъехаться им нельзя: тогда
/// приложение начнёт предлагать действие, которое база отклонит.
final class ChatDeletionTests: XCTestCase {

    // MARK: - Диалог на двоих

    /// У диалога на двоих хозяина нет: переписка общая, и стереть её вправе любой из
    /// двоих. Второму иначе оставалось бы только просить.
    func testEitherSideErasesPair() throws {
        let creator = try chat(members: ["red", "green"], owner: "red", selfId: "red")
        let companion = try chat(members: ["red", "green"], owner: "red", selfId: "green")

        XCTAssertTrue(creator.canErase)
        XCTAssertTrue(companion.canErase)
    }

    /// Диалог, заведённый до появления `owner`, стирается так же: он на двоих, а
    /// создатель для этого решения не нужен вовсе.
    func testLegacyPairWithoutOwnerIsErasable() throws {
        let chat = try chat(members: ["red", "green"], owner: nil, selfId: "green")

        XCTAssertTrue(chat.canErase)
    }

    // MARK: - Группа

    /// Группу стирает только создатель — тот же единственный, кто правит её состав.
    /// Иначе любой из пятерых уносил бы переписку у остальных четверых.
    func testOnlyOwnerErasesGroup() throws {
        let owner = try chat(members: ["red", "green", "blue"], owner: "red", selfId: "red")
        let member = try chat(members: ["red", "green", "blue"], owner: "red", selfId: "green")

        XCTAssertTrue(owner.canErase)
        XCTAssertFalse(member.canErase)
    }

    /// Группа без создателя не стирается никем — ровно как и не меняет состав.
    /// Назначать себя хозяином задним числом нельзя, и это распространяется на удаление.
    func testLegacyGroupWithoutOwnerIsErasableByNobody() throws {
        let first = try chat(members: ["red", "green", "blue"], owner: nil, selfId: "red")
        let second = try chat(members: ["red", "green", "blue"], owner: nil, selfId: "green")

        XCTAssertFalse(first.canErase)
        XCTAssertFalse(second.canErase)
    }

    /// Следствие, о котором стоит знать: «группа» выводится из состава, а не из поля.
    /// Ужавшись до двоих, она с этого момента и есть диалог на двоих — и стереть её
    /// может любой из оставшихся, а не только создатель.
    ///
    /// Тест закрепляет это как решение, а не ловит как оплошность: разойдись здесь
    /// модель с правилами — приложение показало бы свайп, а база ответила бы отказом.
    func testGroupShrunkToTwoBecomesPair() throws {
        let member = try chat(members: ["red", "green"], owner: "blue", selfId: "green")

        XCTAssertTrue(member.canErase)
    }

    // MARK: - Сборка

    private func chat(members: [String], owner: String?, selfId: String) throws -> Chat {
        var data: [String: Any] = ["users": members]

        if let owner {
            data["owner"] = owner
        }

        return try XCTUnwrap(Chat(id: "convo-1", selfId: selfId, data: data))
    }
}
