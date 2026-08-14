//
//  KeyExportViewPresenter.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 14.08.2026.
//

import Foundation
import UIKit
import CoreImage.CIFilterBuiltins

protocol KeyExportViewPresenterProtocol: AnyObject {
    /// Запечатывает ключ под паролем и отдаёт вью строку переноса и её QR.
    ///
    /// Пустой или короткий пароль до шифрования не доходит: об этом сообщается на экране.
    func export(password: String, repeated: String)
}

//MARK: Менеджера у модуля нет, и это осознанно: сюда не ходит ни Firestore, ни сеть
// вообще. Вся работа — `KeyStore` плюс `KeyTransfer`, оба уже общий слой; заводить
// пустой менеджер ради симметрии с остальными модулями значило бы добавить файл, который
// только передаёт вызовы дальше.
final class KeyExportViewPresenter: KeyExportViewPresenterProtocol {

    private weak var view: KeyExportViewProtocol?

    /// Ниже этого пароль не растянет никакой PBKDF2.
    private let minimumPassword = 8

    init(view: KeyExportViewProtocol) {
        self.view = view
    }

    func export(password: String, repeated: String) {
        guard password.count >= minimumPassword else {
            view?.showError("Пароль короче \(minimumPassword) символов. Он единственное, что защищает ключ, — короткий перебирается за минуты")
            return
        }

        guard password == repeated else {
            view?.showError("Пароли не совпадают. Ошибиться здесь дороже обычного: расшифровать перенос без пароля не сможете и вы")
            return
        }

        guard let uid = FirebaseManager.shared.getUser()?.uid else {
            view?.showError("Не удалось определить аккаунт")
            return
        }

        guard let key = KeyStore.existingKey(for: uid) else {
            view?.showError(KeyTransfer.Failure.noKey.localizedDescription)
            return
        }

        do {
            let payload = try KeyTransfer.seal(key, password: password, uid: uid)
            view?.show(payload: payload, qr: qr(from: payload))
        } catch {
            view?.showError(error.localizedDescription)
        }
    }

    //MARK: Строка короткая (около 120 символов), поэтому хватает средней коррекции
    // ошибок — код остаётся некрупным и читается с экрана телефона камерой другого.
    private func qr(from payload: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }

        //MARK: Генератор отдаёт картинку размером с сам код — десятки точек. Растягиваем
        // до показа, иначе на экране будет мыло: интерполяция по умолчанию сглаживает
        // квадраты, а сканеру нужны резкие границы.
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let context = CIContext()

        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }

        return UIImage(cgImage: cgImage)
    }
}
