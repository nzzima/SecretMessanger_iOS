//
//  Message.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 04.08.2026.
//

import Foundation
import MessageKit
import FirebaseFirestore

struct Message: MessageType {
    var sender: SenderType
    var messageId: String
    var sentDate: Date
    var kind: MessageKind

    //MARK: Исходный `Timestamp` из документа, а не только его `Date`. Метка прочтения
    // обязана вернуться в базу **той же самой** величиной: `Timestamp` хранит
    // наносекунды, `Date` — `Double`, и на масштабе 1.8 млрд секунд у него не остаётся
    // разрядов под наносекунды. Обратный перевод `Timestamp(date:)` промахивался вниз на
    // доли микросекунды, и «дочитал ровно до этого сообщения» превращалось в «не дочитал»
    // — галочка не синела, а разницу в логе не разглядеть: секунды совпадают.
    let timestamp: Timestamp

    //MARK: То, что лежит в документе как есть. Расшифровывает презентер — он один
    // знает диалог, а с ним и ключ; модель к Keychain не ходит.
    var body: String
    var isEncrypted: Bool
    var keyVersion: Int

    //MARK: Голосовое отличается от текстового одним полем `type` в документе. Байты
    // лежат не здесь, а в подколлекции `audio` — в сообщении только длительность,
    // которой хватает, чтобы нарисовать ячейку до всякой загрузки.
    var isVoice: Bool
    var duration: Float

    //MARK: Фото устроено так же и по той же причине: снимок лежит в подколлекции
    // `images`, а в сообщении остаются только его размеры. Без них ячейка не знала бы,
    // какой высоты пузырь рисовать, и переписка прыгала бы по мере загрузки картинок.
    var isPhoto: Bool
    var pixels: CGSize

    //MARK: Геопозиция выбивается из этого ряда: у неё нет ни байтов, ни подколлекции —
    // две координаты лежат в самом сообщении, на месте текста, и шифруются как текст.
    // Поэтому и разбираются они уже после расшифровки, а не здесь.
    var isLocation: Bool

    //MARK: В документе лежит только senderId — имя подставляет презентер, он один
    // знает состав диалога. Здесь имя пустое намеренно.
    init(messageId: String, data: [String: Any]) {
        self.messageId = messageId
        self.sender = Sender(senderId: data["senderId"] as? String ?? "", displayName: "")
        self.timestamp = data["date"] as? Timestamp ?? Timestamp(date: Date())
        self.sentDate = self.timestamp.dateValue()

        //MARK: Флаг `enc` разделяет переписку до шифрования и после. Сообщения без
        // него читаются как раньше — сносить историю ради перехода не пришлось.
        self.body = data["message"] as? String ?? ""
        self.isEncrypted = (data["enc"] as? Int ?? 0) == 1
        self.keyVersion = data["v"] as? Int ?? 0
        let type = data["type"] as? String ?? ""

        self.isVoice = type == "audio"
        self.duration = Float(data["duration"] as? Double ?? 0)

        self.isPhoto = type == "image"
        self.pixels = CGSize(width: data["width"] as? Double ?? 0,
                             height: data["height"] as? Double ?? 0)

        self.isLocation = type == "location"

        //MARK: Вид присваивается дважды: сначала заглушкой, потом по-настоящему. Метод,
        // который его собирает, читает поля сообщения, а обратиться к себе можно только
        // когда проинициализировано всё, включая `kind`. Альтернатива — тащить в него
        // шесть параметров и дописывать седьмой на каждый новый вид сообщения.
        self.kind = .text(self.body)
        self.kind = cellKind(text: self.body)
    }

    //MARK: Копия для показа: имя отправителя и уже расшифрованный текст. У голосового и
    // фото расшифровывать в этот момент нечего — байты приезжают отдельно, по нажатию
    // или по появлению ячейки на экране.
    //
    // Копия делается **со всего сообщения**, а не собирается заново из четырёх полей.
    // Раньше собиралась — и `isVoice`, `isPhoto`, `keyVersion` в показанной копии
    // оказывались сброшенными в значения по умолчанию. Ячейка при этом выглядела верно
    // (вид приходил отдельным параметром), а всякий, кто спрашивал у показанного
    // сообщения, фото ли это, получал «нет»: так молча отвалилось открытие снимка на
    // весь экран.
    func displayed(sender: SenderType, text: String) -> Message {
        var copy = self

        copy.sender = sender
        copy.kind = cellKind(text: text)

        return copy
    }

    //MARK: Вид ячейки собирается в одном месте, а не в каждом инициализаторе: видов
    // теперь четыре, и разъехаться им ничего не мешало бы.
    private func cellKind(text: String) -> MessageKind {
        if isVoice {
            return .audio(Voice(messageId: messageId, duration: duration))
        }

        if isPhoto {
            return .photo(Photo(messageId: messageId, pixels: pixels))
        }

        //MARK: Координаты разбираются из уже расшифрованного текста, поэтому настоящая
        // точка получается только в `displayed`. Не разобрались — показываем текст как
        // есть: на этом месте обычно лежит «🔒 Сообщение не расшифровано», и это
        // честнее пустой карты посреди океана.
        if isLocation {
            if let place = Place(payload: text) {
                return .location(place)
            }

            return .text(text)
        }

        return .text(text)
    }
}
