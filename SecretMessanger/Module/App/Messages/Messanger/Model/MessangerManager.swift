//
//  MessangerManager.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 04.08.2026.
//

import Foundation
import FirebaseFirestore

class MessangerManager {

    private let ref = Firestore.firestore()
    private let crypto = ConversationCrypto.shared
    private var messagesListener: ListenerRegistration?
    private var conversationListener: ListenerRegistration?

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
            .addSnapshotListener { snap, err in
                if let err {
                    print("Шапка диалога не читается: \(err.localizedDescription)")
                    return
                }

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
            .addSnapshotListener { snap, err in
                if let err {
                    print("Сообщения не загрузились: \(err.localizedDescription)")
                    return
                }

                guard let docs = snap?.documents else { return }

                completion(docs.map { Message(messageId: $0.documentID, data: $0.data()) })
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

    //MARK: Звук скачивается по нажатию «играть» и кладётся расшифрованным во временную
    // папку: `AVAudioPlayer` умеет играть из файла, а не из памяти. Уже скачанное
    // второй раз не тянем.
    func loadVoice(messageId: String, chat: Chat, completion: @escaping (Result<URL, Error>) -> Void) {
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

                guard let key = self.crypto.key(for: chat, version: chat.keyVersion),
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
