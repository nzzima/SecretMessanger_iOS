//
//  DocumentContractTests.swift
//  SecretMessangerTests
//
//  Created by Nikita Krylov on 12.08.2026.
//

import XCTest
@testable import SecretMessanger

/// Что именно приложение кладёт в Firestore.
///
/// Схема документа — договор сразу с двумя сторонами: с правилами, которые читают из
/// шапки состав и проверяют `senderId`, и со всеми, кто эти документы разбирает. Раньше
/// схему сверяли руками по базе после отправки; теперь это делает набор.
///
/// Сети здесь нет: оба сборщика возвращают словарь, а пишет его отдельный метод.
final class DocumentContractTests: XCTestCase {

    private let manager = MessangerManager()

    //MARK: Отметку о ротации пишет тот же, кто ротирует ключ, — экран состава группы.
    private let members = ChatMembersManager()
    private let date = Date(timeIntervalSince1970: 1_000_000)
    private var savedName = ""

    override func setUp() {
        super.setUp()

        //MARK: Своё имя попадает в шапку из глобального кэша — подменяем на время теста
        // и возвращаем обратно, чтобы не портить состояние соседям.
        savedName = SelfName.current
        SelfName.current = "red"
    }

    override func tearDown() {
        SelfName.current = savedName
        super.tearDown()
    }

    // MARK: - Шапка диалога

    func testHeaderCarriesPreviewAndOwnLogin() {
        let header = manager.header(preview: "шифротекст", chat: encryptedPair(), date: date, encrypted: true)

        XCTAssertEqual(header["lastMessage"] as? String, "шифротекст")
        XCTAssertEqual(header["date"] as? Date, date)
        XCTAssertEqual((header["logins"] as? [String: String])?["red-uid"], "red")
    }

    /// Метка шифрования и версия ключа — по ним список «Чаты» понимает, чем
    /// расшифровывать превью.
    func testEncryptedHeaderCarriesVersion() {
        let header = manager.header(preview: "шифротекст", chat: encryptedPair(), date: date, encrypted: true)

        XCTAssertEqual(header["lastEnc"] as? Int, 1)
        XCTAssertEqual(header["lastV"] as? Int, 7)
    }

    /// Диалоги, начатые до шифрования, ключа не имеют — и полей о нём в шапке быть не
    /// должно, иначе список попытается расшифровать открытый текст.
    func testPlainHeaderHasNoEncryptionFields() {
        let header = manager.header(preview: "привет", chat: plainPair(), date: date, encrypted: false)

        XCTAssertNil(header["lastEnc"])
        XCTAssertNil(header["lastV"])
    }

    /// Отправка **не пишет состав**: у открытого экрана на руках может лежать
    /// устаревший `users`, и такая запись вернула бы удалённого участника обратно —
    /// а правила отклонили бы её целиком, утащив с собой сообщение.
    func testHeaderNeverWritesMembersOrOwner() {
        let header = manager.header(preview: "текст", chat: encryptedGroup(), date: date, encrypted: true)

        XCTAssertNil(header["users"])
        XCTAssertNil(header["owner"])
        XCTAssertNil(header["convoKeys"])
        XCTAssertNil(header["keyVersion"])
    }

    /// Чужие имена в шапке не трогаем: мы их знать не обязаны, а безусловная запись
    /// однажды уже затирала их пустой строкой.
    func testHeaderKeepsOtherPeopleLogins() {
        let header = manager.header(preview: "текст", chat: encryptedPair(), date: date, encrypted: true)
        let logins = header["logins"] as? [String: String]

        XCTAssertEqual(logins?["green-uid"], "green")
    }

    // MARK: - Сообщение

    func testTextMessageShape() {
        let message = manager.message(payload: "шифротекст", chat: encryptedPair(), date: date, encrypted: true)

        XCTAssertEqual(message["senderId"] as? String, "red-uid")
        XCTAssertEqual(message["message"] as? String, "шифротекст")
        XCTAssertEqual(message["date"] as? Date, date)
        XCTAssertEqual(message["enc"] as? Int, 1)
        XCTAssertEqual(message["v"] as? Int, 7)
        XCTAssertNil(message["type"], "у текста типа нет")
    }

    /// `senderId` — то самое поле, которое правила сверяют с вошедшим. Подменить его
    /// нельзя, и браться оно должно из диалога, а не из аргументов.
    func testSenderIdAlwaysComesFromTheChat() {
        let message = manager.message(payload: "x", chat: encryptedGroup(), date: date, encrypted: true)

        XCTAssertEqual(message["senderId"] as? String, "red-uid")
    }

    func testVoiceMessageCarriesDurationAndType() {
        let message = manager.message(payload: "превью", chat: encryptedPair(), date: date,
                                      encrypted: true, extra: ["type": "audio", "duration": 12.5])

        XCTAssertEqual(message["type"] as? String, "audio")
        XCTAssertEqual(message["duration"] as? Double, 12.5)
        XCTAssertNil(message["width"], "у голосового размеров нет")
    }

    func testPhotoMessageCarriesSizeAndType() {
        let message = manager.message(payload: "превью", chat: encryptedPair(), date: date,
                                      encrypted: true,
                                      extra: ["type": "image", "width": 720.0, "height": 1280.0])

        XCTAssertEqual(message["type"] as? String, "image")
        XCTAssertEqual(message["width"] as? Double, 720)
        XCTAssertEqual(message["height"] as? Double, 1280)
        XCTAssertNil(message["duration"], "у фото длительности нет")
    }

    /// У геопозиции нет ни байтов, ни подколлекции: координаты лежат на месте текста и
    /// шифруются как текст. В базе не должно быть видно ни места, ни того, что это место.
    func testLocationMessageCarriesCoordinatesAsPayload() {
        let message = manager.message(payload: "зашифрованные-координаты", chat: encryptedPair(),
                                      date: date, encrypted: true, extra: ["type": "location"])

        XCTAssertEqual(message["type"] as? String, "location")
        XCTAssertEqual(message["message"] as? String, "зашифрованные-координаты")
        XCTAssertNil(message["latitude"])
        XCTAssertNil(message["longitude"])
    }

    func testPlainMessageHasNoEncryptionFields() {
        let message = manager.message(payload: "привет", chat: plainPair(), date: date, encrypted: false)

        XCTAssertNil(message["enc"])
        XCTAssertNil(message["v"])
        XCTAssertEqual(message["message"] as? String, "привет")
    }

    // MARK: - Шапка нового диалога

    /// Группа обязана попадать в список «Чаты» сразу. Без непустого `lastMessage`
    /// ``Conversation`` отбрасывает диалог, а другого входа в группу нет — из
    /// «Контактов» открывается только переписка на двоих. Созданная и не подписанная
    /// группа оказывалась недостижимой навсегда; найдено живьём 26.08.2026.
    func testNewGroupHeaderCarriesCreationMark() {
        let header = manager.newHeader(chat: encryptedGroup(), keys: [:], date: date)

        XCTAssertEqual(header["lastMessage"] as? String, MessangerManager.groupCreatedPreview)
        XCTAssertEqual(header["date"] as? Date, date)
    }

    /// Отметка лежит открытым текстом, и это часть договора, а не недосмотр. Появись
    /// у неё `lastEnc`, участник без записи ключа увидел бы «🔒 Сообщение не
    /// расшифровано» — то есть ровно ту же сломанную группу, от которой отметка спасает.
    func testCreationMarkIsNotEncrypted() {
        let header = manager.newHeader(chat: encryptedGroup(), keys: [:], date: date)

        XCTAssertNil(header["lastEnc"], "отметка обязана читаться и без ключа")
        XCTAssertNil(header["lastV"])
    }

    /// Диалогу на двоих отметка не положена: его шапка заводится при каждом открытии
    /// чата из «Контактов», и список «Чаты» превратился бы в историю просмотров.
    func testNewPairHeaderStaysOutOfTheList() {
        let header = manager.newHeader(chat: encryptedPair(), keys: [:], date: date)

        XCTAssertNil(header["lastMessage"])
        XCTAssertNil(header["date"])
    }

    /// Состав, создатель и ключи едут в шапку независимо от вида диалога — на них
    /// держатся правила Firestore и всё шифрование переписки.
    func testNewHeaderCarriesMembersOwnerAndKeys() {
        let header = manager.newHeader(chat: encryptedGroup(),
                                       keys: ["convoKeys": ["red-uid_1": "запечатанный"], "keyVersion": 1],
                                       date: date)

        XCTAssertEqual(header["users"] as? [String], ["red-uid", "green-uid", "blue-uid"])
        XCTAssertEqual(header["owner"] as? String, "red-uid")
        XCTAssertEqual((header["logins"] as? [String: String])?["red-uid"], "red")
        XCTAssertEqual(header["keyVersion"] as? Int, 1)
    }

    // MARK: - Отметка о смене ключа

    /// Отметка живёт в ленте наравне с сообщениями, значит и правила к ней те же:
    /// `senderId` обязан совпасть с пишущим, иначе Firestore её не примет.
    func testKeyNoticeIsSignedByWriter() {
        let notice = members.keyNotice(chat: encryptedGroup(), date: date)

        XCTAssertEqual(notice["senderId"] as? String, "red-uid")
        XCTAssertEqual(notice["date"] as? Date, date)
        XCTAssertEqual(notice["type"] as? String, "keyRotated")
    }

    /// Содержимого у отметки нет вовсе, и шифровать в ней нечего. Появись здесь `enter`
    /// с флагом `enc`, разбор принял бы её за сообщение и попытался расшифровать пустоту.
    func testKeyNoticeCarriesNoContent() {
        let notice = members.keyNotice(chat: encryptedGroup(), date: date)

        XCTAssertNil(notice["message"])
        XCTAssertNil(notice["enc"])
        XCTAssertNil(notice["v"])
    }

    /// Разбор обязан узнать отметку по одному полю `type` и не спутать её с текстом:
    /// у текстового сообщения этого поля нет вовсе.
    func testParsedNoticeIsRecognised() {
        let notice = Message(messageId: "m1", data: ["senderId": "red-uid", "type": "keyRotated"])
        let text = Message(messageId: "m2", data: ["senderId": "red-uid", "message": "привет"])

        XCTAssertTrue(notice.isKeyNotice)
        XCTAssertFalse(text.isKeyNotice)
    }

    // MARK: - Заготовки

    private func encryptedPair() -> Chat {
        chat(members: ["red-uid", "green-uid"], keyVersion: 7, keys: ["red-uid_7": "запечатанный"])
    }

    private func plainPair() -> Chat {
        chat(members: ["red-uid", "green-uid"], keyVersion: 0, keys: [:])
    }

    private func encryptedGroup() -> Chat {
        chat(members: ["red-uid", "green-uid", "blue-uid"], keyVersion: 7, keys: ["red-uid_7": "запечатанный"])
    }

    private func chat(members: [String], keyVersion: Int, keys: [String: String]) -> Chat {
        Chat(id: "convo-1", selfId: "red-uid", data: [
            "users": members,
            "logins": ["red-uid": "red", "green-uid": "green", "blue-uid": "blue"],
            "owner": "red-uid",
            "convoKeys": keys,
            "keyVersion": keyVersion
        ])!
    }
}
