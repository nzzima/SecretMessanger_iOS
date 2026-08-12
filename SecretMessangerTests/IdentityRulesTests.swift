//
//  IdentityRulesTests.swift
//  SecretMessangerTests
//
//  Created by Nikita Krylov on 12.08.2026.
//

import XCTest
@testable import SecretMessanger

/// Правила вокруг имени и id диалога. Считаются без сети, а ошибка в любом из них
/// стоит дорого: логин участвует в правилах Firestore как ключ документа, а id диалога
/// решает, попадут ли двое в одну переписку или заведут вторую.
final class IdentityRulesTests: XCTestCase {

    // MARK: - Ключ реестра логинов

    /// Ключ в нижнем регистре — иначе `red` и `Red` были бы разными именами, и
    /// уникальность распалась бы ровно на похожих написаниях, ради которых заведена.
    func testRegistryKeyIsCaseInsensitive() {
        XCTAssertEqual(LoginRegistry.key(for: "Red"), LoginRegistry.key(for: "red"))
        XCTAssertEqual(LoginRegistry.key(for: "RED"), "red")
    }

    // MARK: - Приведение логина из префикса почты

    /// Префикс почты приходит с точками и плюсами, а логин участвует в правилах как
    /// ключ документа: мусор в нём означал бы профиль, который невозможно записать.
    func testSanitizeStripsEverythingButLettersDigitsAndUnderscore() {
        XCTAssertEqual(LoginRegistry.sanitize("john.doe+tag", uid: "AbCdEfGh"), "johndoetag")
        XCTAssertEqual(LoginRegistry.sanitize("a_b_c", uid: "AbCdEfGh"), "a_b_c")
    }

    /// Кириллический префикс почты вычищается целиком, остатка не хватает на логин — и
    /// человек получает имя от uid, а не огрызок. Правила требуют латиницы, так что
    /// оставить «_» было бы хуже: такой профиль просто не записался бы.
    func testNonLatinLoginFallsBackEntirely() {
        XCTAssertEqual(LoginRegistry.sanitize("ни_кита", uid: "AbCdEfGh"), "user_abcdef")
    }

    func testSanitizeCapsLoginAtTwentyCharacters() {
        let long = String(repeating: "a", count: 40)

        XCTAssertEqual(LoginRegistry.sanitize(long, uid: "AbCdEfGh").count, 20)
    }

    /// Слишком короткий остаток заменяется именем на основе uid: пустой логин правила
    /// не пропустят, а человек остался бы с аккаунтом, которым нельзя пользоваться.
    func testSanitizeFallsBackToUidWhenTooShort() {
        XCTAssertEqual(LoginRegistry.sanitize("a.", uid: "AbCdEfGh"), "user_abcdef")
        XCTAssertEqual(LoginRegistry.sanitize("", uid: "AbCdEfGh"), "user_abcdef")
    }

    /// Приведённый логин обязан проходить проверку поля — иначе экран регистрации и
    /// автоматическое имя разошлись бы в требованиях.
    func testSanitizedLoginPassesValidation() {
        let validator = FieldValidator()

        XCTAssertTrue(validator.isValid(.login, LoginRegistry.sanitize("john.doe+tag", uid: "AbCdEfGh")))
        XCTAssertTrue(validator.isValid(.login, LoginRegistry.sanitize("", uid: "AbCdEfGh")))
    }

    // MARK: - Проверка полей

    func testLoginRules() {
        let validator = FieldValidator()

        XCTAssertTrue(validator.isValid(.login, "red"))
        XCTAssertTrue(validator.isValid(.login, "user_123"))
        XCTAssertFalse(validator.isValid(.login, "ab"), "короче трёх")
        XCTAssertFalse(validator.isValid(.login, String(repeating: "a", count: 21)), "длиннее двадцати")
        XCTAssertFalse(validator.isValid(.login, "никита"), "не латиница")
        XCTAssertFalse(validator.isValid(.login, "john doe"), "пробел")
    }

    func testEmailRules() {
        let validator = FieldValidator()

        XCTAssertTrue(validator.isValid(.email, "red@gmail.com"))
        XCTAssertFalse(validator.isValid(.email, "red@gmail"))
        XCTAssertFalse(validator.isValid(.email, "redgmail.com"))
    }

    func testPasswordRules() {
        let validator = FieldValidator()

        XCTAssertTrue(validator.isValid(.password, "123456"))
        XCTAssertFalse(validator.isValid(.password, "12345"), "короче шести")
    }

    // MARK: - Id диалога

    /// Оба собеседника независимо приходят к одному и тому же id — на этом держится
    /// то, что чат из «Контактов» попадает в существующую переписку, а не заводит вторую.
    func testPairConversationIdIsTheSameFromBothSides() {
        let red = "KonyrENOrTVuDKDI858pvAQNeNA3"
        let green = "XVsugMAd42ciuM7WtiQXgtSOAmu1"

        XCTAssertEqual(Chat.conversationId(members: [red, green]),
                       Chat.conversationId(members: [green, red]))
    }

    func testPairConversationIdIsSortedPairOfUids() {
        XCTAssertEqual(Chat.conversationId(members: ["b", "a"]), "a_b")
    }

    /// Группа состав в id закодировать не может — он ещё и меняется, — поэтому id
    /// случайный, а единственный источник правды о составе — массив `users`.
    func testGroupConversationIdIsRandom() {
        let members = ["a", "b", "c"]

        XCTAssertNotEqual(Chat.conversationId(members: members), Chat.conversationId(members: members))
    }
}
