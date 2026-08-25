//
//  MessangerManager.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 04.08.2026.
//

import UIKit
import CoreLocation
import FirebaseFirestore

/// Всё, что переписка делает с базой: слушатели, отправка и вложения.
class MessangerManager {

    private let ref = Firestore.firestore()
    private let crypto = ConversationCrypto.shared
    private var messagesListener: ListenerRegistration?
    private var conversationListener: ListenerRegistration?

    //MARK: Участника вычеркнули из состава — правила отказывают его слушателям в тот
    // же миг. Снапшоты перестают приходить, и экран замирает: сообщения не обновляются,
    // отправка молча не доходит, а выглядит всё как обычная переписка. Отказ по правам
    // поэтому идёт отдельным сигналом наверх, а не строкой в консоли.
    var onAccessLost: (() -> Void)?

    //MARK: Диалог стёрли целиком — это не то же самое, что вычеркнули из состава, и
    // словами это разное. Отличить одно от другого можно точно, см. `observeConversation`.
    var onChatDeleted: (() -> Void)?

    //MARK: Общий на оба конца: и отказ по правам, и удаление означают, что экран
    // кончился, а объявить об этом надо один раз. Без него участник, у которого стёрли
    // группу, получил бы поверх «группа удалена» ещё и «вас удалили из группы» — от
    // второго слушателя, которому отказ прилетит следом.
    private var exitAnnounced = false

    //MARK: Здесь же рождается ключ диалога — до первого сообщения, иначе шифровать
    // было бы нечем.
    /// Заводит шапку диалога до подписки на сообщения — и это не порядок ради порядка.
    ///
    /// Правила читают состав участников из шапки через `get()`, а `get()` по
    /// несуществующему документу роняет всю проверку: слушатель в новом чате получал бы
    /// `Missing or insufficient permissions` и умирал насовсем.
    ///
    /// Заодно раздаёт ключ диалога тем, у кого записи ещё нет.
    func ensureConversation(chat: Chat, completion: @escaping () -> Void) {
        let document = ref.collection(.conversation).document(chat.id)

        document.getDocument { [weak self] snap, _ in
            guard let self else { return }

            if let snap, snap.exists {
                //MARK: Состав существующего диалога отсюда не пишется, и это главное
                // изменение с появлением «Участников». У открытого экрана на руках
                // может лежать устаревший состав — из списка чатов, например, — и
                // слепой merge вернул бы вычеркнутого участника обратно. Правила
                // такую запись отклонят целиком, и вместе с ней отвалится чат.
                let existing = Chat(id: chat.id, selfId: chat.selfId, data: snap.data() ?? [:]) ?? chat

                self.heal(chat: existing) { extra in
                    var payload: [String: Any] = ["logins": self.logins(of: chat)]
                    payload.merge(extra) { _, new in new }

                    self.write(payload, to: document, completion: completion)
                }
            } else {
                //MARK: Ошибка чтения сюда же: офлайн `getDocument` отдаёт кэш, так
                // что «не прочиталось» на практике означает «документа нет».
                self.firstKey(for: chat) { extra in
                    var payload: [String: Any] = [
                        "users": chat.members,
                        "logins": self.logins(of: chat),
                        "owner": chat.owner
                    ]
                    payload.merge(extra) { _, new in new }

                    self.write(payload, to: document, completion: completion)
                }
            }
        }
    }

    //MARK: Своё имя в шапку кладём всегда актуальное, а не то, что там лежало.
    // Логин теперь меняется в профиле, а карта `logins` — кэш имён внутри диалога:
    // без этого собеседники видели бы переименовавшегося под старым именем до тех
    // пор, пока диалог не заведут заново. Чужие имена по-прежнему не трогаем — их мы
    // знать не обязаны, а безусловная запись однажды уже затирала их пустой строкой.
    private func logins(of chat: Chat) -> [String: String] {
        var logins = chat.logins

        if !SelfName.current.isEmpty {
            logins[chat.selfId] = SelfName.current
        }

        return logins
    }

    private func write(_ payload: [String: Any], to document: DocumentReference, completion: @escaping () -> Void) {
        document.setData(payload, merge: true) { err in
            if let err {
                print("Диалог не создался: \(err.localizedDescription)")
            }

            completion()
        }
    }

    //MARK: Ключи читаются из `users`, а не берутся на веру от вызывающего. До
    // 24.08.2026 брался только принесённый кэш — и путь «Контакты → профиль → написать»
    // приносил пустоту, потому что собеседник там собирался заново, без открытого ключа.
    // Диалог заводился запечатанным для себя одного, и читать его собеседник не мог.
    // Дверей в чат две, и достаточно было одной забывчивой, чтобы переписка молча не
    // открылась.
    //
    // `users` вдобавок свежее любого кэша: человек мог переустановить приложение и
    // опубликовать новый ключ. Запечатать под устаревший — хуже, чем не запечатать вовсе:
    // запись в `convoKeys` появится, дозапечатывание её не тронет (оно ищет отсутствующие,
    // а не негодные), и переписка останется нечитаемой навсегда.
    //
    // Отсюда же следует, почему у ``Chat`` больше нет поля с чужими ключами: вторая копия
    // рядом с источником — это вторая копия, которая отстанет.
    /// Первый ключ диалога, запечатанный для всех участников и для себя.
    private func firstKey(for chat: Chat, completion: @escaping ([String: Any]) -> Void) {
        let others = chat.members.filter { $0 != chat.selfId }

        PublicKeyDirectory.keys(for: others) { [weak self] fetched in
            guard let self else {
                completion([:])
                return
            }

            var publicKeys = fetched

            //MARK: Свой ключ — из Keychain, а не из профиля: там он и рождается, а в
            // профиле лишь опубликован. Читать его из `users` значило бы зависеть от
            // того, что публикация уже прошла.
            if let mine = PublicKeyDirectory.own(uid: chat.selfId) {
                publicKeys[chat.selfId] = mine
            }

            guard !publicKeys.isEmpty else {
                completion([:])
                return
            }

            let entries = self.crypto.sealed(key: self.crypto.newKey(),
                                             version: 1,
                                             convoId: chat.id,
                                             for: publicKeys)

            completion(entries.isEmpty ? [:] : ["convoKeys": entries, "keyVersion": 1])
        }
    }

    //MARK: Досыпает ключи тем участникам, у кого их нет: человек мог зарегистрироваться
    // до шифрования и опубликовать открытый ключ только теперь. Делает это только
    // создатель — у остальных запись состава и ключей отклонят правила, да и
    // расходиться двум одновременным раздачам ни к чему.
    private func heal(chat: Chat, completion: @escaping ([String: Any]) -> Void) {
        guard chat.isOwner else {
            completion([:])
            return
        }

        let missing = chat.members.filter {
            chat.convoKeys[crypto.entryKey(uid: $0, version: max(chat.keyVersion, 1))] == nil
        }

        guard !missing.isEmpty else {
            completion([:])
            return
        }

        PublicKeyDirectory.keys(for: missing) { [weak self] keys in
            guard let self, !keys.isEmpty else {
                completion([:])
                return
            }

            //MARK: Диалог без ключа вообще — это переписка, начатая до шифрования.
            // Заводим первую версию; старые сообщения так и останутся открытыми, их
            // задним числом не зашифруешь.
            if chat.keyVersion == 0 {
                var all = keys

                if let mine = PublicKeyDirectory.own(uid: chat.selfId) {
                    all[chat.selfId] = mine
                }

                let entries = self.crypto.sealed(key: self.crypto.newKey(), version: 1, convoId: chat.id, for: all)

                completion(entries.isEmpty ? [:] : ["convoKeys": entries, "keyVersion": 1])
            } else {
                //MARK: Опоздавшему отдаём все версии сразу — правила и так дают ему
                // прочитать всю историю, и без старых ключей он увидел бы вместо неё
                // стену нерасшифрованного.
                let entries = self.crypto.sealedAllVersions(chat: chat, for: keys)

                completion(entries.isEmpty ? [:] : ["convoKeys": entries])
            }
        }
    }

    //MARK: Метка кладётся в шапку одной записью и **дозаписью**: `merge: true` сливает
    // вложенную карту, так что чужие отметки остаются на месте. На это же опирается
    // правило — оно требует, чтобы в `readUpTo` изменился ровно свой ключ и ничей больше.
    //
    // Записывается отметка **сообщения**, а не текущее время: так обе стороны сравнивают
    // числа с одних часов, отправительских, и разошедшиеся часы двух телефонов не
    // превращаются в галочки на непрочитанном.
    //
    // И записывается именно `Timestamp` из документа, не пересобранный из `Date`.
    // `Timestamp(date:)` теряет наносекунды — `Date` это `Double`, а на масштабе 1.8 млрд
    // секунд разрядов под них не остаётся. Промах вниз на 9.5e-07 секунды превращал
    // «дочитал ровно до этого сообщения» в «не дочитал», и галочка не синела. Поймано
    // только логом с шестью знаками: в секундах обе величины выглядят одинаково.
    /// Отмечает, что мы дочитали переписку до этого сообщения.
    func markRead(chat: Chat, upTo timestamp: Timestamp) {
        ref.collection(.conversation).document(chat.id).setData([
            "readUpTo": [chat.selfId: timestamp]
        ], merge: true) { err in
            //MARK: Молча: метка — украшение, и ронять из-за неё экран или тревожить
            // человека незачем. Не дошла — дойдёт со следующим сообщением.
            if let err {
                print("Метка прочтения не записалась: \(err.localizedDescription)")
            }
        }
    }

    //MARK: Шапку слушаем, а не читаем однократно: состав группы теперь меняется на
    // ходу, и добавленный участник должен появиться в заголовке и в подписях к
    // сообщениям без перезахода в чат. Через неё же приезжает новая версия ключа
    // после ротации.
    /// Слушает шапку: состав, имена и ключи меняются при живом экране.
    func observeConversation(chat: Chat, completion: @escaping (Chat) -> Void) {
        conversationListener?.remove()

        conversationListener = ref
            .collection(.conversation)
            .document(chat.id)
            .addSnapshotListener { [weak self] snap, err in
                if let err {
                    self?.handleListenerError(err, convoId: chat.id, what: "Шапка диалога")
                    return
                }

                //MARK: Шапки нет — диалог стёрли. От «нас вычеркнули из состава» это
                // отличается надёжно: `ensureConversation` заводит шапку до подписки,
                // так что к этому моменту она заведомо существовала. Вычёркивание
                // приходит отказом по правам, удаление — вот этим пустым снапшотом.
                if let snap, !snap.exists {
                    self?.announceDeleted()
                    return
                }

                //MARK: Шапка прочиталась — значит мы в составе, и отметка о выходе
                // из этого диалога устарела.
                ChatExit.forget(chat.id)

                guard let data = snap?.data(),
                      let updated = Chat(id: chat.id, selfId: chat.selfId, data: data) else { return }

                completion(updated)
            }
    }

    /// Слушает последние сообщения диалога.
    ///
    /// - Note: `limit(toLast:)`, а не `limit(to:)` — второй отдал бы **первые** полсотни
    ///   сообщений, то есть самые старые.
    func observeMessages(convoId: String, completion: @escaping ([Message]) -> Void) {
        messagesListener?.remove()

        messagesListener = ref
            .collection(.conversation)
            .document(convoId)
            .collection(.messages)
            .order(by: "date")
            .limit(toLast: 50)
            .addSnapshotListener { [weak self] snap, err in
                if let err {
                    self?.handleListenerError(err, convoId: convoId, what: "Сообщения")
                    return
                }

                guard let docs = snap?.documents else { return }

                completion(docs.map { Message(messageId: $0.documentID, data: $0.data()) })
            }
    }

    //MARK: `permissionDenied` от слушателя означает ровно одно: нас больше нет в
    // составе диалога. Всё остальное — связь, и оно лечится само, поэтому уходит в
    // консоль, как и раньше.
    private func handleListenerError(_ error: Error, convoId: String, what: String) {
        let error = error as NSError

        guard error.domain == FirestoreErrorDomain,
              error.code == FirestoreErrorCode.permissionDenied.rawValue else {
            print("\(what) не читаются: \(error.localizedDescription)")
            return
        }

        //MARK: Флаг ставим до всех проверок: слушателей два, отказ приходит каждому,
        // и без него сообщение задвоилось бы, а отметку о добровольном выходе снял бы
        // первый — второй счёл бы тот же выход удалением.
        guard !exitAnnounced else { return }
        exitAnnounced = true

        //MARK: Слушатели снимаем сами: после отказа они уже ничего не принесут, а
        // висеть до закрытия экрана будут.
        stopObserving()

        guard !ChatExit.wasVoluntary(convoId) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.onAccessLost?()
        }
    }

    //MARK: Слушатели снимаются здесь по той же причине, что и при отказе: диалога
    // больше нет, приносить им нечего, а висеть до закрытия экрана они будут.
    private func announceDeleted() {
        guard !exitAnnounced else { return }
        exitAnnounced = true

        stopObserving()

        DispatchQueue.main.async { [weak self] in
            self?.onChatDeleted?()
        }
    }

    /// Снимает оба слушателя — шапки и сообщений.
    func stopObserving() {
        messagesListener?.remove()
        messagesListener = nil

        conversationListener?.remove()
        conversationListener = nil
    }

    //MARK: Голосовое пишется в два документа: звук — в подколлекцию `audio`,
    // сообщение — туда же, куда текстовые. Разделение не косметическое: слушатель
    // чата держит последние 50 сообщений и перечитывает их при каждом изменении, так
    // что запись внутри сообщения означала бы мегабайты на каждое открытие чата.
    //
    // Звук пишется первым: сообщение появляется у собеседника мгновенно через
    // слушателя, и к этому моменту играть уже должно быть что.
    /// Отправляет голосовое: запись шифруется и ложится в подколлекцию `audio`.
    ///
    /// В самом сообщении остаётся только длительность — её хватает, чтобы сверстать
    /// ячейку. Байты в сообщении означали бы мегабайты на каждое открытие любого чата:
    /// подписка перечитывает последние полсотни сообщений при каждом изменении.
    func sendVoice(url: URL, duration: TimeInterval, chat: Chat, completion: @escaping (Error?) -> Void) {
        guard let raw = try? Data(contentsOf: url) else {
            completion(VoiceRecorderError.failed)
            return
        }

        guard let key = crypto.currentKey(for: chat) else {
            completion(ConversationCryptoError.noKey)
            return
        }

        guard let sealed = try? CryptoBox.seal(raw, with: key),
              let preview = crypto.encrypt(MessangerManager.voicePreview, chat: chat) else {
            completion(ConversationCryptoError.noKey)
            return
        }

        let messageId = UUID().uuidString
        let date = Date()
        let conversation = ref.collection(.conversation).document(chat.id)

        conversation.collection(.audio).document(messageId).setData([
            "senderId": chat.selfId,
            "data": sealed
        ]) { [weak self] err in
            guard let self, err == nil else {
                completion(err)
                return
            }

            //MARK: Превью в списке чатов — обычный текст, зашифрованный тем же ключом.
            // Без него диалог с одними голосовыми пропал бы из «Чатов»: `Conversation`
            // отбрасывает шапку с пустым `lastMessage`.
            self.write(header: self.header(preview: preview, chat: chat, date: date, encrypted: true),
                       message: self.message(payload: preview, chat: chat, date: date, encrypted: true,
                                             extra: ["type": "audio", "duration": duration]),
                       id: messageId,
                       chat: chat,
                       completion: completion)
        }
    }

    static let voicePreview = "🎤 Голосовое сообщение"
    static let photoPreview = "📷 Фото"

    // MARK: - Отправка: общая часть

    /// Шапка диалога — то, что видно в списке «Чаты».
    ///
    /// Своё имя пишется в неё при каждой отправке (см. ``logins(of:)``), превью — тем же
    /// шифротекстом, что и само сообщение: оставь его открытым, и последняя реплика
    /// каждого диалога лежала бы в базе читаемой.
    ///
    /// - Parameters:
    ///   - preview: то, что покажет список: сам текст или пометка вроде «📷 Фото».
    ///   - encrypted: диалоги, начатые до шифрования, ключа не имеют и пишут открытым.
    //MARK: Не `private` ровно затем, чтобы схему документа сторожили тесты: она — договор
    // с правилами Firestore и со всеми, кто эти документы читает, и молча разъехаться ей
    // нельзя. Снаружи модуля метод всё равно не виден.
    func header(preview: String, chat: Chat, date: Date, encrypted: Bool) -> [String: Any] {
        var header: [String: Any] = [
            "logins": logins(of: chat),
            "lastMessage": preview,
            "date": date
        ]

        if encrypted {
            header["lastEnc"] = 1
            header["lastV"] = chat.keyVersion
        }

        return header
    }

    /// Сам документ сообщения. `extra` — поля, которые есть только у своего вида:
    /// длительность у голосового, размеры у фото, тип у всего, кроме текста.
    func message(payload: String, chat: Chat, date: Date,
                 encrypted: Bool, extra: [String: Any] = [:]) -> [String: Any] {
        var message: [String: Any] = [
            "senderId": chat.selfId,
            "message": payload,
            "date": date
        ]

        if encrypted {
            message["enc"] = 1
            message["v"] = chat.keyVersion
        }

        message.merge(extra) { _, new in new }

        return message
    }

    /// Пишет шапку, а следом — сообщение, и порядок здесь обязателен.
    ///
    /// С появлением групп участие в сообщениях проверяется правилами по документу шапки,
    /// поэтому к моменту записи сообщения она должна быть актуальна. Все четыре вида
    /// отправки — текст, голос, фото, геопозиция — ходят этим путём.
    private func write(header: [String: Any], message: [String: Any], id: String,
                       chat: Chat, completion: @escaping (Error?) -> Void) {
        let conversation = ref.collection(.conversation).document(chat.id)

        conversation.setData(header, merge: true) { err in
            guard err == nil else {
                completion(err)
                return
            }

            conversation.collection(.messages).document(id).setData(message) { err in
                completion(err)
            }
        }
    }

    //MARK: Фото уходит теми же тремя записями, что и голосовое: байты — в свою
    // подколлекцию, превью — в шапку, само сообщение — к остальным. Подколлекция здесь
    // не про порядок в базе: чат держит последние 50 сообщений и перечитывает их при
    // каждом изменении, так что снимок внутри сообщения означал бы мегабайты трафика на
    // каждое чужое «привет».
    /// Отправляет фото: подгоняет под бюджет, шифрует и кладёт в подколлекцию `images`.
    ///
    /// В сообщении едут размеры — иначе пузырь не сверстать до загрузки, и переписка
    /// прыгала бы по мере прихода картинок.
    ///
    /// - Returns: через `completion` — ``PhotoEncoderError/tooLarge``, если снимок не
    ///   уместился даже после трёх заходов сжатия.
    func sendPhoto(_ image: UIImage, chat: Chat, completion: @escaping (Error?) -> Void) {
        guard let key = crypto.currentKey(for: chat) else {
            completion(ConversationCryptoError.noKey)
            return
        }

        //MARK: Сжатие уводим с главного потока: снимок с камеры — это 12 мегапикселей,
        // и перерисовка с перекодированием в JPEG заметно подвешивает интерфейс.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            guard let encoded = PhotoEncoder.encode(image) else {
                DispatchQueue.main.async { completion(PhotoEncoderError.tooLarge) }
                return
            }

            guard let sealed = try? CryptoBox.seal(encoded.data, with: key),
                  let preview = self.crypto.encrypt(MessangerManager.photoPreview, chat: chat) else {
                DispatchQueue.main.async { completion(ConversationCryptoError.noKey) }
                return
            }

            DispatchQueue.main.async {
                self.upload(sealed: sealed,
                            preview: preview,
                            size: encoded.size,
                            jpeg: encoded.data,
                            chat: chat,
                            completion: completion)
            }
        }
    }

    private func upload(sealed: Data,
                        preview: String,
                        size: CGSize,
                        jpeg: Data,
                        chat: Chat,
                        completion: @escaping (Error?) -> Void) {
        let messageId = UUID().uuidString
        let date = Date()
        let conversation = ref.collection(.conversation).document(chat.id)

        //MARK: Своё же фото кладём в кэш сразу — иначе отправитель увидит серую заглушку
        // и приложение скачает из базы снимок, который лежит у него в руках. В кэш идёт
        // сжатая версия, а не оригинал: показывать надо ровно то, что увидят остальные.
        if let visible = UIImage(data: jpeg) {
            PhotoCache.shared.store(visible, for: messageId)
        }

        conversation.collection(.images).document(messageId).setData([
            "senderId": chat.selfId,
            "data": sealed
        ]) { [weak self] err in
            guard let self, err == nil else {
                completion(err)
                return
            }

            //MARK: Превью в списке чатов — обычный текст под тем же ключом. Без него
            // диалог из одних фотографий пропал бы из «Чатов»: `Conversation` отбрасывает
            // шапку с пустым `lastMessage`.
            self.write(header: self.header(preview: preview, chat: chat, date: date, encrypted: true),
                       message: self.message(payload: preview, chat: chat, date: date, encrypted: true,
                                             extra: ["type": "image",
                                                     "width": Double(size.width),
                                                     "height": Double(size.height)]),
                       id: messageId,
                       chat: chat,
                       completion: completion)
        }
    }

    static let locationPreview = "📍 Геопозиция"

    //MARK: Геопозиция уходит двумя записями, а не тремя: подколлекции у неё нет, две
    // координаты помещаются в само сообщение. Шифруются они как обычный текст и тем же
    // ключом — в базу уходит шифротекст, по которому не сказать даже, что это координаты.
    //
    // Ключ обязателен, как у фото: положить в базу открытую точку на карте мы не станем.
    /// Отправляет точку на карте.
    ///
    /// Единственное вложение без своей подколлекции: две координаты помещаются в само
    /// сообщение. Шифруются они как текст, поэтому в базе не видно ни места, ни того,
    /// что это вообще место.
    func sendLocation(_ location: CLLocation, chat: Chat, completion: @escaping (Error?) -> Void) {
        guard let payload = crypto.encrypt(Place.payload(for: location), chat: chat),
              let preview = crypto.encrypt(MessangerManager.locationPreview, chat: chat) else {
            completion(ConversationCryptoError.noKey)
            return
        }

        let date = Date()

        //MARK: В превью списка «Чаты» уходит «📍 Геопозиция», а в сообщение — сами
        // координаты: показывать в списке широту с долготой незачем, а хранить их
        // где-то ещё, кроме сообщения, — тем более.
        write(header: header(preview: preview, chat: chat, date: date, encrypted: true),
              message: message(payload: payload, chat: chat, date: date, encrypted: true,
                               extra: ["type": "location"]),
              id: UUID().uuidString,
              chat: chat,
              completion: completion)
    }

    //MARK: Снимок тянется, когда ячейка появилась на экране, и остаётся в памяти. На
    // диск расшифрованное не ложится — в отличие от голосовых, которым файл нужен для
    // проигрывателя.
    //
    // Версия ключа приходит от сообщения, а не берётся текущая: после ротации (кого-то
    // удалили из группы) текущий ключ старое фото не откроет.
    /// Скачивает и расшифровывает снимок — по появлению ячейки, а не при открытии чата.
    ///
    /// - Parameter version: версия ключа **самого сообщения**. После ротации снимки,
    ///   отправленные раньше, открываются только прежним ключом.
    func loadPhoto(messageId: String,
                   version: Int,
                   chat: Chat,
                   completion: @escaping (Result<UIImage, Error>) -> Void) {
        if let cached = PhotoCache.shared.image(for: messageId) {
            completion(.success(cached))
            return
        }

        ref
            .collection(.conversation)
            .document(chat.id)
            .collection(.images)
            .document(messageId)
            .getDocument { [weak self] snap, err in
                if let err {
                    completion(.failure(err))
                    return
                }

                guard let self,
                      let sealed = snap?.data()?["data"] as? Data else {
                    completion(.failure(ConversationCryptoError.noKey))
                    return
                }

                guard let key = self.crypto.key(for: chat, version: version),
                      let raw = try? CryptoBox.open(sealed, with: key),
                      let image = UIImage(data: raw) else {
                    completion(.failure(ConversationCryptoError.noKey))
                    return
                }

                PhotoCache.shared.store(image, for: messageId)
                completion(.success(image))
            }
    }

    //MARK: Звук скачивается по нажатию «играть» и кладётся расшифрованным во временную
    // папку: `AVAudioPlayer` умеет играть из файла, а не из памяти. Уже скачанное
    // второй раз не тянем.
    //MARK: Версия ключа берётся у самого сообщения: текущая после ротации открывает
    // только то, что записано после неё, а голосовое, отправленное до удаления
    // участника, запечатано предыдущей.
    /// Скачивает голосовое и кладёт расшифрованное во временный файл.
    ///
    /// Файл нужен потому, что `AVAudioPlayer` играет из файла, а не из байтов — в
    /// отличие от фото, которое так и остаётся в памяти.
    func loadVoice(messageId: String, version: Int, chat: Chat, completion: @escaping (Result<URL, Error>) -> Void) {
        let url = Voice.cacheURL(messageId: messageId)

        guard !Voice.isCached(messageId: messageId) else {
            completion(.success(url))
            return
        }

        ref
            .collection(.conversation)
            .document(chat.id)
            .collection(.audio)
            .document(messageId)
            .getDocument { [weak self] snap, err in
                if let err {
                    completion(.failure(err))
                    return
                }

                guard let self,
                      let sealed = snap?.data()?["data"] as? Data else {
                    completion(.failure(ConversationCryptoError.noKey))
                    return
                }

                guard let key = self.crypto.key(for: chat, version: version),
                      let raw = try? CryptoBox.open(sealed, with: key) else {
                    completion(.failure(ConversationCryptoError.noKey))
                    return
                }

                do {
                    try raw.write(to: url)
                    completion(.success(url))
                } catch {
                    completion(.failure(error))
                }
            }
    }

    /// Отправляет текстовое сообщение.
    ///
    /// Единственный вид отправки без `completion`: экран решает судьбу набранного текста
    /// заранее — по тому, есть ли ключ, — а неудача самой записи ему уже ничего не даёт.
    func send(text: String, chat: Chat) {
        let date = Date()

        //MARK: `lastMessage` шифруется тем же ключом, что и само сообщение. Оставить
        // его открытым значило бы выложить последнюю реплику каждого диалога в базу
        // открытым текстом — от шифрования остался бы один вид.
        //
        //MARK: Диалоги, начатые до шифрования, ключа не имеют, и текст в них до сих пор
        // уходит открытым: их история и так лежит в базе читаемой. Вложения так не умеют
        // вовсе — нет ключа, нет отправки.
        let payload = chat.isEncrypted ? crypto.encrypt(text, chat: chat) : text

        guard let payload else {
            print("Сообщение не зашифровано: нет ключа диалога")
            return
        }

        //MARK: `users` в этой записи нет намеренно — состав правит только создатель
        // через «Участников». Заводит шапку `ensureConversation`, и до первой отправки
        // она всегда уже есть.
        write(header: header(preview: payload, chat: chat, date: date, encrypted: chat.isEncrypted),
              message: message(payload: payload, chat: chat, date: date, encrypted: chat.isEncrypted),
              id: UUID().uuidString,
              chat: chat) { err in
            if let err {
                print("Сообщение не отправилось: \(err.localizedDescription)")
            }
        }
    }
}
