//
//  DocumentParsingTests.swift
//  SecretMessangerTests
//
//  Created by Nikita Krylov on 12.08.2026.
//

import XCTest
import FirebaseFirestore
@testable import SecretMessanger

/// Обратная сторона договора: что приложение вычитывает из документов.
///
/// Все эти инициализаторы принимают словарь, поэтому проверяются без сети. Разбор
/// в этом проекте намеренно снисходителен — отсутствующее поле даёт значение по
/// умолчанию, а не падение, — и именно поэтому его надо сторожить: снисходительный
/// разбор молча превращает опечатку в имени поля в пустой экран.
final class DocumentParsingTests: XCTestCase {

    // MARK: - Шапка диалога

    func testChatReadsMembersLoginsAndKeys() throws {
        let chat = try XCTUnwrap(Chat(id: "convo-1", selfId: "red", data: [
            "users": ["red", "green"],
            "logins": ["red": "red", "green": "green"],
            "owner": "red",
            "convoKeys": ["red_1": "запечатанный"],
            "keyVersion": 1
        ]))

        XCTAssertEqual(chat.members, ["red", "green"])
        XCTAssertEqual(chat.title, "green", "название — все, кроме себя")
        XCTAssertTrue(chat.isOwner)
        XCTAssertTrue(chat.isEncrypted)
        XCTAssertEqual(chat.keyVersion, 1)
    }

    /// Диалог, в котором нас нет, показать нечем — и это единственная причина, по
    /// которой инициализатор падающий.
    func testChatIsNilWhenWeAreNotAMember() {
        XCTAssertNil(Chat(id: "convo-1", selfId: "stranger", data: ["users": ["red", "green"]]))
        XCTAssertNil(Chat(id: "convo-1", selfId: "red", data: [:]), "без users читать нечего")
    }

    /// У диалогов, заведённых до появления поля `owner`, состав не меняет никто:
    /// назначать себя создателем задним числом правила не дают.
    func testChatWithoutOwnerHasNobodyInCharge() throws {
        let chat = try XCTUnwrap(Chat(id: "convo-1", selfId: "red", data: ["users": ["red", "green"]]))

        XCTAssertFalse(chat.isOwner)
        XCTAssertFalse(chat.isEncrypted, "переписка до шифрования")
        XCTAssertEqual(chat.keyVersion, 0)
    }

    func testGroupIsThreeOrMore() throws {
        let pair = try XCTUnwrap(Chat(id: "c", selfId: "red", data: ["users": ["red", "green"]]))
        let group = try XCTUnwrap(Chat(id: "c", selfId: "red", data: ["users": ["red", "green", "blue"]]))

        XCTAssertFalse(pair.isGroup)
        XCTAssertTrue(group.isGroup)
    }

    /// Открытые ключи живут в `users`, а не в шапке, и ``Chat`` их не носит вовсе —
    /// ни из базы, ни из выбранных контактов. Поле с ними убрано 24.08.2026: копия рядом
    /// с источником однажды отстала и оставила диалог запечатанным для одного человека.
    ///
    /// Тест сторожит именно это: посторонние ключи в документе разбор игнорирует и в
    /// шапке диалога их не появляется — брать их оттуда больше неоткуда.
    func testChatFromDatabaseCarriesNoPublicKeys() throws {
        let chat = try XCTUnwrap(Chat(id: "c", selfId: "red", data: [
            "users": ["red", "green"],
            "publicKeys": ["green": "чужой-ключ"],
            "convoKeys": ["red_1": "запечатанный"],
            "keyVersion": 1
        ]))

        //MARK: Ключ диалога — тот, что запечатан лично для нас, — при этом на месте:
        // без него переписка не открылась бы.
        XCTAssertEqual(chat.convoKeys["red_1"], "запечатанный")
        XCTAssertEqual(chat.keyVersion, 1)
    }

    // MARK: - Строка списка «Чаты»

    /// Диалог без единого сообщения — штатное состояние: шапка заводится при открытии
    /// чата, чтобы правила могли проверить состав. В списке ему делать нечего.
    func testConversationIsNilUntilSomebodyWrites() {
        XCTAssertNil(Conversation(id: "c", selfId: "red", data: [
            "users": ["red", "green"],
            "lastMessage": ""
        ]))
    }

    func testConversationReadsPreviewAndDate() throws {
        let date = Date(timeIntervalSince1970: 1_000_000)

        let conversation = try XCTUnwrap(Conversation(id: "c", selfId: "red", data: [
            "users": ["red", "green"],
            "logins": ["green": "green"],
            "lastMessage": "привет",
            "date": Timestamp(date: date)
        ]))

        XCTAssertEqual(conversation.lastMessage, "привет")
        XCTAssertEqual(conversation.date, date)
        XCTAssertEqual(conversation.title, "green")
    }

    /// Нерасшифрованное превью показывается прямо, а не пустой строкой: так выглядит
    /// диалог, ключ от которого остался на другом устройстве.
    func testUndecryptablePreviewSaysSo() throws {
        let conversation = try XCTUnwrap(Conversation(id: "c", selfId: "red", data: [
            "users": ["red", "green"],
            "lastMessage": "не-расшифровать",
            "lastEnc": 1,
            "lastV": 1
        ]))

        XCTAssertEqual(conversation.lastMessage, "🔒 Сообщение не расшифровано")
    }

    /// У диалога на двоих аватар — собеседника, у группы его нет: одной картинкой
    /// нескольких участников не показать.
    func testCompanionIsOnlyDefinedForPairs() throws {
        let pair = try XCTUnwrap(Conversation(id: "c", selfId: "red", data: [
            "users": ["red", "green"], "lastMessage": "x"
        ]))
        let group = try XCTUnwrap(Conversation(id: "c", selfId: "red", data: [
            "users": ["red", "green", "blue"], "lastMessage": "x"
        ]))

        XCTAssertEqual(pair.companionId, "green")
        XCTAssertNil(group.companionId)
    }

    // MARK: - Сообщение

    func testTextMessageParsing() {
        let message = Message(messageId: "m1", data: [
            "senderId": "red",
            "message": "привет",
            "enc": 1,
            "v": 3
        ])

        XCTAssertEqual(message.sender.senderId, "red")
        XCTAssertEqual(message.body, "привет")
        XCTAssertTrue(message.isEncrypted)
        XCTAssertEqual(message.keyVersion, 3)
        XCTAssertFalse(message.isVoice)
        XCTAssertFalse(message.isPhoto)
        XCTAssertFalse(message.isLocation)
    }

    /// Сообщения, написанные до шифрования, читаются как раньше — сносить историю ради
    /// перехода не пришлось.
    func testMessageWithoutEncryptionFlagIsPlain() {
        let message = Message(messageId: "m1", data: ["senderId": "red", "message": "привет"])

        XCTAssertFalse(message.isEncrypted)
        XCTAssertEqual(message.keyVersion, 0)
    }

    func testVoiceMessageParsing() {
        let message = Message(messageId: "m1", data: [
            "senderId": "red", "message": "превью", "type": "audio", "duration": 12.5
        ])

        XCTAssertTrue(message.isVoice)
        XCTAssertEqual(message.duration, 12.5)
    }

    func testPhotoMessageParsing() {
        let message = Message(messageId: "m1", data: [
            "senderId": "red", "message": "превью", "type": "image",
            "width": 720.0, "height": 1280.0
        ])

        XCTAssertTrue(message.isPhoto)
        XCTAssertEqual(message.pixels, CGSize(width: 720, height: 1280))
    }

    func testLocationMessageParsing() {
        let message = Message(messageId: "m1", data: [
            "senderId": "red", "message": "55.5,37.5", "type": "location"
        ])

        XCTAssertTrue(message.isLocation)
        XCTAssertFalse(message.isPhoto)
    }

    /// Копия для показа делается со **всего** сообщения. Когда её собирали заново из
    /// четырёх полей, `isPhoto` и `keyVersion` в копии сбрасывались, и открытие снимка
    /// на весь экран тихо переставало работать — при верно выглядящей ячейке.
    func testDisplayedCopyKeepsEveryField() {
        let message = Message(messageId: "m1", data: [
            "senderId": "red", "message": "шифротекст", "type": "image",
            "enc": 1, "v": 2, "width": 720.0, "height": 1280.0
        ])

        let shown = message.displayed(sender: Sender(senderId: "red", displayName: "red"),
                                      text: "расшифрованное")

        XCTAssertTrue(shown.isPhoto)
        XCTAssertEqual(shown.keyVersion, 2)
        XCTAssertTrue(shown.isEncrypted)
        XCTAssertEqual(shown.pixels, CGSize(width: 720, height: 1280))
        XCTAssertEqual(shown.sender.displayName, "red")
    }

    // MARK: - Профили

    /// Логин показывается собеседникам; у старых документов его может не быть, и тогда
    /// на его месте имя — иначе экран выглядел бы пустым.
    func testChatUserFallsBackFromLoginToName() {
        XCTAssertEqual(ChatUser(id: "u", userInfo: ["login": "red", "name": "Красный"]).login, "red")
        XCTAssertEqual(ChatUser(id: "u", userInfo: ["name": "Красный"]).login, "Красный")
        XCTAssertEqual(ChatUser(id: "u", userInfo: [:]).login, "")
    }

    func testAvatarVersionDefaultsToZero() {
        XCTAssertEqual(ChatUser(id: "u", userInfo: [:]).avatarVersion, 0)
        XCTAssertEqual(ActiveUser(id: "u", userInfo: [:]).avatarVersion, 0)
        XCTAssertEqual(ProfileInfo(data: [:]).avatarVersion, 0)
        XCTAssertEqual(ChatUser(id: "u", userInfo: ["avatarVersion": 4]).avatarVersion, 4)
    }

    /// Граница приватности проходит по модели, а не по вёрстке: почта в публичный
    /// профиль не парсится вовсе, чтобы не просочиться в интерфейс по недосмотру.
    func testProfileInfoNeverCarriesEmail() {
        let profile = ProfileInfo(data: [
            "login": "red", "name": "Красный", "someInfo": "заметка", "email": "red@gmail.com"
        ])

        XCTAssertEqual(profile.login, "red")
        XCTAssertEqual(profile.someInfo, "заметка")

        let mirror = Mirror(reflecting: profile)
        XCTAssertFalse(mirror.children.contains { ($0.value as? String) == "red@gmail.com" })
    }
}
