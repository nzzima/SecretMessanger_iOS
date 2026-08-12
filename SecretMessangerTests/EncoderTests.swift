//
//  EncoderTests.swift
//  SecretMessangerTests
//
//  Created by Nikita Krylov on 12.08.2026.
//

import XCTest
@testable import SecretMessanger

/// Подготовка картинок к отправке. Обе величины — бюджет и сторона — придуманы не на
/// глаз, и тест сторожит именно их: превышение бюджета означает документ, который
/// Firestore откажется принять, а это потеря уже выбранного фото.
final class EncoderTests: XCTestCase {

    // MARK: - Аватар

    func testAvatarIsAlwaysSquare() throws {
        let encoded = try XCTUnwrap(AvatarEncoder.encode(image(width: 1152, height: 2048)))
        let decoded = try XCTUnwrap(UIImage(data: encoded))

        XCTAssertEqual(decoded.size.width, AvatarEncoder.side)
        XCTAssertEqual(decoded.size.height, AvatarEncoder.side)
    }

    func testAvatarFitsBudget() throws {
        let encoded = try XCTUnwrap(AvatarEncoder.encode(image(width: 4288, height: 2848)))

        XCTAssertLessThanOrEqual(encoded.count, AvatarEncoder.budget)
    }

    /// Маленькую картинку не растягиваем сверх нужного: квадрат всё равно 320, но
    /// проверяем, что кодировщик её принимает, а не падает.
    func testTinyAvatarIsAccepted() throws {
        let encoded = try XCTUnwrap(AvatarEncoder.encode(image(width: 40, height: 40)))
        let decoded = try XCTUnwrap(UIImage(data: encoded))

        XCTAssertEqual(decoded.size.width, AvatarEncoder.side)
    }

    // MARK: - Фото в переписке

    func testPhotoFitsBudget() throws {
        let encoded = try XCTUnwrap(PhotoEncoder.encode(image(width: 4288, height: 2848)))

        XCTAssertLessThanOrEqual(encoded.data.count, PhotoEncoder.budget)
    }

    /// Пропорции снимка сохраняются: это не аватар, тут не кадрируют.
    func testPhotoKeepsAspectRatio() throws {
        let encoded = try XCTUnwrap(PhotoEncoder.encode(image(width: 2000, height: 1000)))

        XCTAssertEqual(encoded.size.width / encoded.size.height, 2, accuracy: 0.01)
    }

    func testPhotoIsCappedByLongSide() throws {
        let encoded = try XCTUnwrap(PhotoEncoder.encode(image(width: 4000, height: 3000)))

        XCTAssertLessThanOrEqual(max(encoded.size.width, encoded.size.height), PhotoEncoder.maxSide)
    }

    /// Размеры возвращаются вместе с байтами — по ним верстается пузырь до того, как
    /// картинка приедет. Ноль здесь означал бы схлопнувшуюся ячейку.
    func testPhotoReturnsUsableSize() throws {
        let encoded = try XCTUnwrap(PhotoEncoder.encode(image(width: 800, height: 600)))

        XCTAssertGreaterThan(encoded.size.width, 0)
        XCTAssertGreaterThan(encoded.size.height, 0)
    }

    // MARK: -

    /// Картинка с неоднородным содержимым: сплошная заливка сжимается неправдоподобно
    /// хорошо, и бюджет на ней ничего бы не проверил.
    private func image(width: CGFloat, height: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            for x in stride(from: 0, to: width, by: 4) {
                for y in stride(from: 0, to: height, by: 4) {
                    UIColor(red: .random(in: 0...1),
                            green: .random(in: 0...1),
                            blue: .random(in: 0...1),
                            alpha: 1).setFill()

                    context.fill(CGRect(x: x, y: y, width: 4, height: 4))
                }
            }
        }
    }
}
