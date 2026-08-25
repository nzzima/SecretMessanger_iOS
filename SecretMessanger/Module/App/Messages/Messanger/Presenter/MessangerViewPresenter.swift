//
//  MessangerViewPresenter.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 04.08.2026.
//

import UIKit

/// Что переписка обещает своему экрану.
protocol MessangerViewPresenterProtocol: AnyObject {
    var chat: Chat { get }

    /// Заголовок: имена всех, кроме себя. У группы меняется вместе с составом.
    var title: String { get }

    /// Вторая строка шапки: «в сети», «в сети 20 минут назад». Пустая у группы и пока
    /// присутствие собеседника неизвестно.
    var status: String { get }
    var isGroup: Bool { get }
    var selfSender: Sender { get }
    var messages: [Message] { get }
    var isRecording: Bool { get }

    /// Сколько уже пишем. Экран считает по нему **вниз**: упереться в потолок значило
    /// бы потерять наговорённое в момент отправки.
    var recordingTime: TimeInterval { get }

    /// - Returns: `false` — сообщение не принято (нет ключа диалога). Набранный текст
    ///   в этом случае остаётся в поле, а не пропадает вместе с неудачей.
    @discardableResult func sendMessage(text: String) -> Bool
    func startRecording()
    func finishRecording()

    /// Отмена: запись выбрасывается, ничего не отправляется.
    func cancelRecording()
    func playVoice(messageId: String, play: @escaping (URL) -> Void)
    func sendPhoto(_ image: UIImage)

    /// Тянет снимок по появлению ячейки. `nil` — показать замок в пузыре.
    func loadPhoto(messageId: String, completion: @escaping (UIImage?) -> Void)
    func shareLocation()
    func avatar(for uid: String) -> UIImage?

    /// Прочитали ли **все** остальные это наше сообщение. Для чужих — всегда `false`:
    /// галочки ставятся только на своих.
    func isRead(_ message: Message) -> Bool

    /// Экран показался или ушёл. Метка прочтения ставится только пока переписку
    /// действительно видно.
    func screenBecameVisible()
    func screenWentAway()
}

class MessangerViewPresenter: MessangerViewPresenterProtocol {

    weak var view: MessangerViewProtocol?

    private let messangerManager = MessangerManager()
    private let recorder = VoiceRecorder()
    private let locations = LocationProvider()

    //MARK: Только у диалога на двоих. В группе присутствие пришлось бы сводить по всем
    // сразу, и во второй строке шапки оказалось бы «в сети 2 из 5» — цифра, которую
    // некуда приткнуть и незачем читать.
    private var presence: PresenceObserver?

    //MARK: Состав чата больше не константа: создатель может добавить или убрать
    // участника, пока экран открыт. Отсюда `var` и слушатель на шапку.
    private(set) var chat: Chat

    private var incoming: [Message] = []
    private(set) var messages: [Message] = []

    private var isSharingLocation = false
    private var isAskingMicrophone = false

    //MARK: Метка ставится, только пока переписку **видно на самом деле**, и условий здесь
    // два, а не одно. Экран может быть открыт и при этом не виден: приложение свернули в
    // карман или сверху лежит экран «Участники». В обоих случаях «прочитано» означало бы
    // «чат был открыт», и человек, которому показали две галочки, ждал бы ответа от того,
    // кто ничего не видел.
    private var isOnScreen = false
    private var isForeground = true

    private var isVisible: Bool { isOnScreen && isForeground }

    private var lifecycleObservers: [NSObjectProtocol] = []

    //MARK: Докуда мы уже отметились. Без этого каждый снапшот шапки — а она меняется на
    // любую отправку и на любую чужую метку — заказывал бы новую запись, и две
    // переписывающиеся стороны гоняли бы метки по кругу до бесконечности.
    private var markedUpTo: Date?

    //MARK: Аватары участников. В шапке диалога их нет и не будет: там кэшируются
    // логины, потому что они нужны на каждое сообщение, а картинка — одна на человека
    // и берётся из своего хранилища.
    private var avatars: [String: UIImage] = [:]

    var title: String { chat.title }
    private(set) var status = ""
    var isGroup: Bool { chat.isGroup }

    var selfSender: Sender {
        Sender(senderId: chat.selfId, displayName: chat.login(for: chat.selfId))
    }

    var isRecording: Bool { recorder.isRecording }
    var recordingTime: TimeInterval { recorder.currentTime }

    required init(view: MessangerViewProtocol?, chat: Chat) {
        self.view = view
        self.chat = chat

        //MARK: Потолок по длительности срабатывает сам, без участия экрана, поэтому
        // об окончании записи надо сообщить — иначе интерфейс остался бы в режиме
        // записи, которой уже нет.
        recorder.onAutoStop = { [weak self] url, duration in
            DispatchQueue.main.async {
                self?.view?.recordingStopped()
                self?.upload(url: url, duration: duration)
            }
        }

        start()
    }

    deinit {
        messangerManager.stopObserving()
        presence?.stop()
        lifecycleObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    private func start() {
        //MARK: Отказ по правам приходит сюда: нас удалили из группы, и дальше экран
        // всё равно ничего не покажет и ничего не отправит.
        messangerManager.onAccessLost = { [weak self] in
            self?.view?.accessLost()
        }

        //MARK: Диалог стёрли — экрану тоже конец, но по другой причине и другими
        // словами: удалили переписку, а не нас из неё.
        messangerManager.onChatDeleted = { [weak self] in
            self?.view?.chatDeleted()
        }

        messangerManager.ensureConversation(chat: chat) { [weak self] in
            self?.observeConversation()
            self?.observeMessages()
        }

        loadAvatars()
        observePresence()
        observeLifecycle()
    }

    //MARK: Слушатель на один документ, а не на коллекцию: в чате нас интересует ровно
    // один человек, и коллекция присутствия приносила бы сюда удары пульса всех
    // остальных — с чтением за каждый.
    private func observePresence() {
        guard !chat.isGroup,
              let companion = chat.members.first(where: { $0 != chat.selfId }) else { return }

        let observer = PresenceObserver(scope: .one(companion))

        observer.start { [weak self] _ in
            guard let self else { return }

            //MARK: Пустая строка — это «не знаем», а не «офлайн». Человек, ни разу не
            // заходивший после появления присутствия, документа не имеет вовсе, и
            // подписывать его «в сети никогда» было бы неправдой.
            let updated = observer.status(of: companion)?.text() ?? ""

            guard updated != self.status else { return }

            self.status = updated
            self.view?.reloadTitle()
        }

        presence = observer
    }

    //MARK: Версии аватаров читаются разом по составу, а картинки — по одной. Всё это
    // один раз при открытии чата и ещё раз, когда в группу кого-то добавили: аватар,
    // сменённый собеседником посреди разговора, догонит при следующем открытии.
    // Слушатель на чужие профили ради кружка в углу баббла того не стоит.
    private func loadAvatars() {
        AvatarStore.shared.versions(for: chat.members) { [weak self] versions in
            versions.forEach { uid, version in
                AvatarStore.shared.load(uid: uid, version: version) { [weak self] image in
                    guard let self, let image else { return }

                    self.avatars[uid] = image
                    self.view?.reloadAvatars()
                }
            }
        }
    }

    func avatar(for uid: String) -> UIImage? {
        avatars[uid]
    }

    func isRead(_ message: Message) -> Bool {
        guard message.sender.senderId == chat.selfId else { return false }

        return chat.isRead(message.sentDate, author: chat.selfId)
    }

    func screenBecameVisible() {
        isOnScreen = true
        markReadIfNeeded()
    }

    func screenWentAway() {
        isOnScreen = false
    }

    //MARK: Уход в фон экран не замечает — `viewWillDisappear` на это не срабатывает, —
    // поэтому слушаем приложение напрямую. Без этого чат, свёрнутый в карман вместе с
    // телефоном, продолжал бы отмечать входящие прочитанными.
    private func observeLifecycle() {
        let center = NotificationCenter.default

        lifecycleObservers = [
            center.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                               object: nil, queue: .main) { [weak self] _ in
                self?.isForeground = false
            },
            center.addObserver(forName: UIApplication.willEnterForegroundNotification,
                               object: nil, queue: .main) { [weak self] _ in
                self?.isForeground = true
                self?.markReadIfNeeded()
            }
        ]
    }

    //MARK: Отмечаемся по дате последнего сообщения, а не по «сейчас»: читающий возвращает
    // ту же дату, что стоит в документе, и обе стороны сравнивают числа с одних часов.
    private func markReadIfNeeded() {
        guard isVisible, let last = incoming.last else { return }

        //MARK: Своё же сообщение метить незачем — оно и так наше, а лишняя запись
        // разбудила бы слушателя шапки у собеседника без всякой пользы.
        guard last.sender.senderId != chat.selfId else { return }

        guard markedUpTo == nil || last.sentDate > markedUpTo! else { return }

        markedUpTo = last.sentDate
        messangerManager.markRead(chat: chat, upTo: last.timestamp)
    }

    private func observeConversation() {
        messangerManager.observeConversation(chat: chat) { [weak self] chat in
            guard let self else { return }

            //MARK: Состав изменился — значит появился кто-то, чьего аватара мы ещё не
            // видели. Удалённый останется в словаре, но его сообщения из переписки
            // никуда не делись, и подписывать их безликим кружком незачем.
            let joined = Set(chat.members).subtracting(self.chat.members)

            self.chat = chat

            if !joined.isEmpty {
                self.loadAvatars()
            }

            //MARK: Имена берутся из состава, поэтому подписи под сообщениями надо
            // пересобрать: иначе добавленный участник остался бы безымянным до
            // перезахода в чат.
            self.rebuildMessages()

            DispatchQueue.main.async {
                self.view?.reloadTitle()
                self.view?.reloadCollection()
            }
        }
    }

    private func observeMessages() {
        messangerManager.observeMessages(convoId: chat.id) { [weak self] messages in
            guard let self else { return }

            self.incoming = messages
            self.rebuildMessages()
            self.markReadIfNeeded()

            DispatchQueue.main.async {
                self.view?.reloadCollection()
            }
        }
    }

    //MARK: Отправитель в базе хранится одним лишь id — имя подставляется из состава
    // чата, он же лежит в шапке диалога. Работает и для группы, а не только для пары.
    // Здесь же расшифровка: ключ приезжает в шапке, а она у презентера под рукой.
    private func rebuildMessages() {
        messages = incoming.map { message in
            message.displayed(sender: sender(for: message.sender.senderId),
                              text: text(of: message))
        }
    }

    //MARK: Нерасшифрованное сообщение — не сбой, который можно замолчать: так
    // выглядит переписка, ключ от которой остался на другом устройстве. Показываем
    // это прямо, а не пустым баблом.
    private func text(of message: Message) -> String {
        guard message.isEncrypted else { return message.body }

        return ConversationCrypto.shared.decrypt(message.body, chat: chat, version: message.keyVersion)
            ?? "🔒 Сообщение не расшифровано"
    }

    private func sender(for id: String) -> Sender {
        Sender(senderId: id, displayName: chat.login(for: id))
    }

    //MARK: Возвращает, приняли ли сообщение к отправке: по этому ответу экран решает,
    // очищать поле ввода или оставить набранное человеку.
    @discardableResult
    func sendMessage(text: String) -> Bool {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }

        //MARK: Без ключа диалога шифровать нечем. Молчать тут нельзя: набранное
        // просто исчезало бы из поля, а в переписке не появлялось — тот самый отказ
        // без реакции, из-за которого экран входа когда-то выглядел сломанным.
        guard !chat.isEncrypted || ConversationCrypto.shared.currentKey(for: chat) != nil else {
            view?.showError("Ключ этого диалога вам ещё не выдан — сообщение не отправлено. Ключ появится, когда создатель чата откроет его.")
            return false
        }

        //MARK: В список локально не добавляем: Firestore отдаёт собственную запись
        // обратно через слушателя сразу, ещё до подтверждения сервером. Ручная
        // вставка продублировала бы сообщение.
        messangerManager.send(text: text, chat: chat)

        return true
    }

    // MARK: - Голосовые

    func startRecording() {
        //MARK: Без ключа шифровать запись нечем — говорим об этом до того, как
        // человек наговорит две минуты впустую.
        guard !chat.isEncrypted || ConversationCrypto.shared.currentKey(for: chat) != nil else {
            view?.showError(ConversationCryptoError.noKey.localizedDescription)
            return
        }

        switch recorder.access {
        case .granted:
            record()
        case .denied:
            view?.showError(VoiceRecorderError.microphoneDenied.localizedDescription)
        case .undetermined:
            askMicrophone()
        }
    }

    //MARK: Разрешение спрашивалось внутри старта записи — и первое удержание уходило
    // на него целиком: системное окно перехватывает касание, палец отпускают уже на
    // нём, а запись не начиналась. Со стороны это выглядело сломанной кнопкой, ровно
    // тем молчаливым отказом, который в этом проекте выпалывали уже трижды.
    //
    // Спросить заранее, при открытии чата, было бы проще всего — но это разрешение,
    // которое просят до того, как оно понадобилось. Поэтому первое удержание честно
    // занимается разрешением и говорит, что делать дальше.
    private func askMicrophone() {
        guard !isAskingMicrophone else { return }

        isAskingMicrophone = true

        recorder.requestAccess { [weak self] granted in
            guard let self else { return }

            self.isAskingMicrophone = false

            guard granted else {
                self.view?.showError(VoiceRecorderError.microphoneDenied.localizedDescription)
                return
            }

            //MARK: Записывать отсюда нечего: пока человек отвечал системе, кнопку он
            // отпустил, и запись пошла бы без единого нажатого пальца — остановить её
            // было бы уже нечем.
            self.view?.microphoneGranted()
        }
    }

    private func record() {
        VoicePlayer.shared.stop()

        recorder.start { [weak self] err in
            guard let err else {
                self?.view?.recordingStarted()
                return
            }

            self?.view?.showError(err.localizedDescription)
        }
    }

    func finishRecording() {
        view?.recordingStopped()

        //MARK: `nil` здесь — запись короче секунды, то есть промах по кнопке. Ругаться
        // на это незачем, отправлять тоже.
        guard let recorded = recorder.stop() else { return }

        upload(url: recorded.url, duration: recorded.duration)
    }

    func cancelRecording() {
        recorder.cancel()
        view?.recordingStopped()
    }

    private func upload(url: URL, duration: TimeInterval) {
        messangerManager.sendVoice(url: url, duration: duration, chat: chat) { [weak self] err in
            //MARK: Файл убираем в любом случае: отправился он или нет, во временной
            // папке ему делать нечего — звук уже либо в базе, либо потерян.
            try? FileManager.default.removeItem(at: url)

            guard let err else { return }

            DispatchQueue.main.async {
                self?.view?.showError(err.localizedDescription)
            }
        }
    }

    func playVoice(messageId: String, play: @escaping (URL) -> Void) {
        messangerManager.loadVoice(messageId: messageId, version: version(of: messageId), chat: chat) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let url):
                    play(url)
                case .failure(let err):
                    self?.view?.showError(err.localizedDescription)
                }
            }
        }
    }

    //MARK: Каким ключом запечатано вложение, знает только само сообщение: после ротации
    // в группе в одной переписке лежат записи разных версий. Для сообщений до шифрования
    // версии нет вовсе — там и расшифровывать нечего.
    private func version(of messageId: String) -> Int {
        incoming.first { $0.messageId == messageId }?.keyVersion ?? chat.keyVersion
    }

    // MARK: - Фото

    func sendPhoto(_ image: UIImage) {
        //MARK: Условие строже, чем у текста, и намеренно. Текст в диалогах, начатых до
        // шифрования, до сих пор уходит открытым — история там и так лежит в базе
        // читаемой, и запрет ничего бы не спас. Снимков в таких диалогах нет ни одного,
        // так что открытым фото не будет никогда: нет ключа — нет отправки.
        guard ConversationCrypto.shared.currentKey(for: chat) != nil else {
            view?.showError(ConversationCryptoError.noKey.localizedDescription)
            return
        }

        messangerManager.sendPhoto(image, chat: chat) { [weak self] err in
            guard let err else { return }

            DispatchQueue.main.async {
                self?.view?.showError(err.localizedDescription)
            }
        }
    }

    // MARK: - Геопозиция

    //MARK: Порядок такой: сначала ключ, потом доступ, потом координаты. Спрашивать
    // разрешение и ловить спутники ради сообщения, которое всё равно нечем зашифровать, —
    // только злить.
    func shareLocation() {
        guard ConversationCrypto.shared.currentKey(for: chat) != nil else {
            view?.showError(ConversationCryptoError.noKey.localizedDescription)
            return
        }

        //MARK: Пока одна отправка идёт, вторую не начинаем: на живом телефоне фикс
        // занимает секунды, и за это время по скрепке успевают нажать ещё раз.
        guard !isSharingLocation else { return }

        isSharingLocation = true
        view?.locationSearchStarted()

        locations.ensureAccess { [weak self] result in
            guard let self else { return }

            DispatchQueue.main.async {
                switch result {
                case .success(true):
                    self.locateAndSend()
                case .success(false):
                    //MARK: Приблизительную точку молча не отправляем. Человек мог оставить
                    // «Точно: Выкл.» осознанно, но собеседник этого не увидит: на карте
                    // будет обычная метка, только за километр от места. Спрашиваем до
                    // фикса, а не после, чтобы не тратить его время впустую.
                    self.stopSharing()
                    self.view?.confirmApproximateLocation { [weak self] in
                        guard let self, !self.isSharingLocation else { return }

                        self.isSharingLocation = true
                        self.view?.locationSearchStarted()
                        self.locateAndSend()
                    }
                case .failure(let err):
                    self.fail(with: err)
                }
            }
        }
    }

    private func locateAndSend() {
        locations.locate { [weak self] result in
            guard let self else { return }

            DispatchQueue.main.async {
                switch result {
                case .success(let location):
                    self.messangerManager.sendLocation(location, chat: self.chat) { err in
                        DispatchQueue.main.async {
                            self.stopSharing()

                            guard let err else { return }

                            self.view?.showError(err.localizedDescription)
                        }
                    }
                case .failure(let err):
                    self.fail(with: err)
                }
            }
        }
    }

    private func fail(with error: Error) {
        stopSharing()
        view?.showError(error.localizedDescription)
    }

    private func stopSharing() {
        isSharingLocation = false
        view?.locationSearchStopped()
    }

    //MARK: `nil` означает «показать замок вместо снимка». Алерт здесь не годится:
    // загрузка идёт на появление ячейки, и на прокрутке нерасшифруемой переписки человек
    // получил бы очередь окошек. Замок в пузыре говорит ровно то же самое и по делу.
    func loadPhoto(messageId: String, completion: @escaping (UIImage?) -> Void) {
        messangerManager.loadPhoto(messageId: messageId, version: version(of: messageId), chat: chat) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let image):
                    completion(image)
                case .failure(let err):
                    print("Фото не открылось: \(err.localizedDescription)")
                    completion(nil)
                }
            }
        }
    }
}
