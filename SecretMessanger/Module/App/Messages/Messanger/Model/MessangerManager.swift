//
//  MessangerManager.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 04.08.2026.
//

import UIKit
import CoreLocation
import FirebaseFirestore

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

    private var accessLostHandled = false

    //MARK: Шапку диалога заводим до того, как подписываться на сообщения. Правила
    // берут состав участников из неё через `get()`, а `get()` по несуществующему
    // документу роняет проверку: в только что созданном чате слушатель получал бы
    // «Missing or insufficient permissions» и умирал насовсем.
    //
    // Здесь же рождается ключ диалога — до первого сообщения, иначе шифровать было бы
    // нечем.
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
                var payload: [String: Any] = [
                    "users": chat.members,
                    "logins": self.logins(of: chat),
                    "owner": chat.owner
                ]
                payload.merge(self.firstKey(for: chat)) { _, new in new }

                self.write(payload, to: document, completion: completion)
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

    //MARK: Первый ключ диалога, запечатанный для тех, чьи открытые ключи пришли
    // вместе с выбранными контактами, и для себя.
    private func firstKey(for chat: Chat) -> [String: Any] {
        var publicKeys = chat.knownPublicKeys

        if let mine = PublicKeyDirectory.own(uid: chat.selfId) {
            publicKeys[chat.selfId] = mine
        }

        guard !publicKeys.isEmpty else { return [:] }

        let entries = crypto.sealed(key: crypto.newKey(), version: 1, convoId: chat.id, for: publicKeys)

        guard !entries.isEmpty else { return [:] }

        return ["convoKeys": entries, "keyVersion": 1]
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

    //MARK: Шапку слушаем, а не читаем однократно: состав группы теперь меняется на
    // ходу, и добавленный участник должен появиться в заголовке и в подписях к
    // сообщениям без перезахода в чат. Через неё же приезжает новая версия ключа
    // после ротации.
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

                //MARK: Шапка прочиталась — значит мы в составе, и отметка о выходе
                // из этого диалога устарела.
                ChatExit.forget(chat.id)

                guard let data = snap?.data(),
                      let updated = Chat(id: chat.id, selfId: chat.selfId, data: data) else { return }

                completion(updated)
            }
    }

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
        guard !accessLostHandled else { return }
        accessLostHandled = true

        //MARK: Слушатели снимаем сами: после отказа они уже ничего не принесут, а
        // висеть до закрытия экрана будут.
        stopObserving()

        guard !ChatExit.wasVoluntary(convoId) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.onAccessLost?()
        }
    }

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
            conversation.setData([
                "logins": self.logins(of: chat),
                "lastMessage": preview,
                "lastEnc": 1,
                "lastV": chat.keyVersion,
                "date": date
            ], merge: true) { err in
                guard err == nil else {
                    completion(err)
                    return
                }

                conversation.collection(.messages).document(messageId).setData([
                    "senderId": chat.selfId,
                    "message": preview,
                    "type": "audio",
                    "duration": duration,
                    "enc": 1,
                    "v": chat.keyVersion,
                    "date": date
                ]) { err in
                    completion(err)
                }
            }
        }
    }

    static let voicePreview = "🎤 Голосовое сообщение"
    static let photoPreview = "📷 Фото"

    //MARK: Фото уходит теми же тремя записями, что и голосовое: байты — в свою
    // подколлекцию, превью — в шапку, само сообщение — к остальным. Подколлекция здесь
    // не про порядок в базе: чат держит последние 50 сообщений и перечитывает их при
    // каждом изменении, так что снимок внутри сообщения означал бы мегабайты трафика на
    // каждое чужое «привет».
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
            conversation.setData([
                "logins": self.logins(of: chat),
                "lastMessage": preview,
                "lastEnc": 1,
                "lastV": chat.keyVersion,
                "date": date
            ], merge: true) { err in
                guard err == nil else {
                    completion(err)
                    return
                }

                conversation.collection(.messages).document(messageId).setData([
                    "senderId": chat.selfId,
                    "message": preview,
                    "type": "image",
                    "width": Double(size.width),
                    "height": Double(size.height),
                    "enc": 1,
                    "v": chat.keyVersion,
                    "date": date
                ]) { err in
                    completion(err)
                }
            }
        }
    }

    static let locationPreview = "📍 Геопозиция"

    //MARK: Геопозиция уходит двумя записями, а не тремя: подколлекции у неё нет, две
    // координаты помещаются в само сообщение. Шифруются они как обычный текст и тем же
    // ключом — в базу уходит шифротекст, по которому не сказать даже, что это координаты.
    //
    // Ключ обязателен, как у фото: положить в базу открытую точку на карте мы не станем.
    func sendLocation(_ location: CLLocation, chat: Chat, completion: @escaping (Error?) -> Void) {
        guard let payload = crypto.encrypt(Place.payload(for: location), chat: chat),
              let preview = crypto.encrypt(MessangerManager.locationPreview, chat: chat) else {
            completion(ConversationCryptoError.noKey)
            return
        }

        let date = Date()
        let conversation = ref.collection(.conversation).document(chat.id)

        conversation.setData([
            "logins": logins(of: chat),
            "lastMessage": preview,
            "lastEnc": 1,
            "lastV": chat.keyVersion,
            "date": date
        ], merge: true) { err in
            guard err == nil else {
                completion(err)
                return
            }

            //MARK: В превью списка «Чаты» уходит «📍 Геопозиция», а в сообщение — сами
            // координаты: показывать в списке широту с долготой незачем, а хранить их
            // где-то ещё, кроме сообщения, — тем более.
            conversation.collection(.messages).document(UUID().uuidString).setData([
                "senderId": chat.selfId,
                "message": payload,
                "type": "location",
                "enc": 1,
                "v": chat.keyVersion,
                "date": date
            ]) { err in
                completion(err)
            }
        }
    }

    //MARK: Снимок тянется, когда ячейка появилась на экране, и остаётся в памяти. На
    // диск расшифрованное не ложится — в отличие от голосовых, которым файл нужен для
    // проигрывателя.
    //
    // Версия ключа приходит от сообщения, а не берётся текущая: после ротации (кого-то
    // удалили из группы) текущий ключ старое фото не откроет.
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

    func send(text: String, chat: Chat) {
        let date = Date()
        let conversation = ref.collection(.conversation).document(chat.id)

        //MARK: `lastMessage` шифруется тем же ключом, что и само сообщение. Оставить
        // его открытым значило бы выложить последнюю реплику каждого диалога в базу
        // открытым текстом — от шифрования остался бы один вид.
        let payload = chat.isEncrypted ? crypto.encrypt(text, chat: chat) : text

        guard let payload else {
            print("Сообщение не зашифровано: нет ключа диалога")
            return
        }

        //MARK: Шапка обновляется ПЕРЕД записью сообщения, и это не вкусовщина: с
        // появлением групп участие в сообщениях проверяется правилами по документу
        // шапки, поэтому к моменту записи сообщения она должна быть актуальна.
        //
        // `users` в этой записи нет намеренно — состав правит только создатель через
        // «Участников». Заводит шапку `ensureConversation`, и до первой отправки она
        // всегда уже есть.
        var header: [String: Any] = [
            "logins": logins(of: chat),
            "lastMessage": payload,
            "date": date
        ]

        if chat.isEncrypted {
            header["lastEnc"] = 1
            header["lastV"] = chat.keyVersion
        }

        conversation.setData(header, merge: true) { err in
            if let err {
                print("Диалог не обновился: \(err.localizedDescription)")
                return
            }

            var message: [String: Any] = [
                "senderId": chat.selfId,
                "message": payload,
                "date": date
            ]

            if chat.isEncrypted {
                message["enc"] = 1
                message["v"] = chat.keyVersion
            }

            conversation
                .collection(.messages)
                .document(UUID().uuidString)
                .setData(message) { err in
                    if let err {
                        print("Сообщение не отправилось: \(err.localizedDescription)")
                    }
                }
        }
    }
}
