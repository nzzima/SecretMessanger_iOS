//
//  PlacePayloadTests.swift
//  SecretMessangerTests
//
//  Created by Nikita Krylov on 12.08.2026.
//

import XCTest
import CoreLocation
@testable import SecretMessanger

/// Полезная нагрузка геопозиции — строка «широта,долгота», и она шифруется целиком.
/// Разбирается уже после расшифровки, поэтому кривая строка обязана давать `nil`, а не
/// точку в Гвинейском заливе.
final class PlacePayloadTests: XCTestCase {

    func testPayloadSurvivesRoundTrip() throws {
        let moscow = CLLocation(latitude: 55.753930, longitude: 37.620795)

        let payload = Place.payload(for: moscow)
        let parsed = try XCTUnwrap(Place(payload: payload))

        XCTAssertEqual(parsed.location.coordinate.latitude, moscow.coordinate.latitude, accuracy: 0.000001)
        XCTAssertEqual(parsed.location.coordinate.longitude, moscow.coordinate.longitude, accuracy: 0.000001)
    }

    /// Дробная часть печатается через точку независимо от локали устройства. С запятой
    /// строка «широта,долгота» распалась бы на четыре куска вместо двух.
    func testPayloadUsesDotRegardlessOfLocale() {
        let payload = Place.payload(for: CLLocation(latitude: 55.5, longitude: 37.5))

        XCTAssertEqual(payload, "55.500000,37.500000")
        XCTAssertEqual(payload.split(separator: ",").count, 2)
    }

    func testNegativeCoordinatesSurvive() throws {
        let payload = Place.payload(for: CLLocation(latitude: -33.865143, longitude: -151.209900))
        let parsed = try XCTUnwrap(Place(payload: payload))

        XCTAssertEqual(parsed.location.coordinate.latitude, -33.865143, accuracy: 0.000001)
        XCTAssertEqual(parsed.location.coordinate.longitude, -151.209900, accuracy: 0.000001)
    }

    func testMalformedPayloadIsRejected() {
        XCTAssertNil(Place(payload: ""))
        XCTAssertNil(Place(payload: "55.75"), "одна координата")
        XCTAssertNil(Place(payload: "55.75,37.62,10"), "лишняя часть")
        XCTAssertNil(Place(payload: "широта,долгота"))
        XCTAssertNil(Place(payload: "🔒 Сообщение не расшифровано"))
    }

    /// Координаты вне земного диапазона — тоже мусор, даже если это числа.
    func testOutOfRangeCoordinatesAreRejected() {
        XCTAssertNil(Place(payload: "955.000000,37.000000"))
        XCTAssertNil(Place(payload: "55.000000,537.000000"))
    }
}
