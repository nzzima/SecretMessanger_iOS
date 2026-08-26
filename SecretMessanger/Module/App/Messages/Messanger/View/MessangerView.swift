//
//  MessangerView.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 04.08.2026.
//

import UIKit
import MapKit
import PhotosUI
import MessageKit
import InputBarAccessoryView

protocol MessangerViewProtocol: AnyObject {
    func reloadCollection()
    func reloadAvatars()
    func reloadTitle()
    func recordingStarted()
    func recordingStopped()
    func microphoneGranted()
    func accessLost()
    func chatDeleted()
    func locationSearchStarted()
    func locationSearchStopped()
    func confirmApproximateLocation(onSend: @escaping () -> Void)
    func showError(_ message: String)
}

class MessangerView: MessagesViewController, MessangerViewProtocol {

    var presenter: MessangerViewPresenterProtocol!

    private var recordingTimer: Timer?
    private var hintTimer: Timer?

    //MARK: Микрофон стоит справа, рядом с отправкой: и то и другое — «отправить сейчас»,
    // а слева живут вложения. Запись идёт по удержанию: у голосового нет состояния
    // «набрано, но не отправлено», и отдельная кнопка «стоп» ему не нужна.
    private lazy var micButton: InputBarButtonItem = {
        $0.image = UIImage(systemName: "mic.fill")
        $0.tintColor = .accent
        $0.setSize(CGSize(width: 36, height: 36), animated: false)
        $0.addGestureRecognizer(micGesture)
        return $0
    }(InputBarButtonItem())

    private lazy var micGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleMic(_:)))

    //MARK: Скрепка вместо ряда кнопок по одной на каждый вид вложения: их уже два, и
    // панель ввода не резиновая. Меню открывается по нажатию (`showsMenuAsPrimaryAction`),
    // без удержания — держать приходится микрофон, и путать эти два жеста ни к чему.
    private lazy var attachButton: InputBarButtonItem = {
        $0.image = UIImage(systemName: "paperclip")
        $0.tintColor = .accent
        $0.setSize(CGSize(width: 36, height: 36), animated: false)
        $0.showsMenuAsPrimaryAction = true
        $0.menu = UIMenu(children: [
            UIAction(title: "Фото", image: UIImage(systemName: "photo")) { [weak self] _ in
                self?.pickPhoto()
            },
            UIAction(title: "Геопозиция", image: UIImage(systemName: "mappin.and.ellipse")) { [weak self] _ in
                self?.presenter.shareLocation()
            }
        ])
        return $0
    }(InputBarButtonItem())

    //MARK: Фото, которые уже тянутся из базы, и те, что не открылись. Без первого набора
    // каждая перерисовка ячейки запускала бы ещё одну загрузку того же снимка, без
    // второго — бесконечно повторялась бы неудачная.
    private var loadingPhotos: Set<String> = []
    private var failedPhotos: Set<String> = []

    //MARK: Подсказка на месте поля ввода, пока идёт долгое дело: запись голосового или
    // поиск спутников. И то и другое иначе выглядит как «нажал, и ничего не произошло» —
    // на симуляторе геопозиция приезжает мгновенно, а на живом телефоне это секунды, в
    // помещении и десятки секунд.
    private lazy var statusLabel: UILabel = {
        $0.font = .systemFont(ofSize: 16)
        $0.isHidden = true
        return $0
    }(UILabel())

    //MARK: Шапка на две строки — имя и присутствие. Обычного `title` для этого мало:
    // он одна строка и красится общим оформлением панели. Само `title` при этом
    // остаётся выставленным — из него iOS берёт подпись кнопки «назад» на предыдущем
    // экране, а её `titleView` не заменяет.
    private lazy var headerTitle: UILabel = {
        $0.font = .systemFont(ofSize: 17, weight: .semibold)
        $0.textColor = .ink
        $0.textAlignment = .center
        return $0
    }(UILabel())

    private lazy var headerStatus: UILabel = {
        $0.font = .systemFont(ofSize: 12)
        $0.textColor = .inkDim
        $0.textAlignment = .center
        return $0
    }(UILabel())

    //MARK: Первый из двух знаков шифрования во всём приложении. Приглушённый и рядом с
    // именем: говорит один раз за экран, что переписка запечатана. На каждом бабле такой
    // замок был бы шумом, а не доверием — приложение, без конца напоминающее о своей
    // безопасности, выглядит менее безопасным, а не более.
    //
    //MARK: Показывается только там, где шифрование действительно есть. Диалоги, начатые
    // до его появления, ключа не имеют, и замок над ними был бы враньём — тем более
    // дорогим, что верят ему на слово.
    private lazy var lockIcon: UIImageView = {
        $0.image = UIImage(systemName: "lock.fill")
        $0.tintColor = .inkDim
        $0.contentMode = .scaleAspectFit
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.widthAnchor.constraint(equalToConstant: 11).isActive = true
        $0.heightAnchor.constraint(equalToConstant: 13).isActive = true
        return $0
    }(UIImageView())

    private lazy var titleRow: UIStackView = {
        $0.axis = .horizontal
        $0.alignment = .center
        $0.spacing = 5
        return $0
    }(UIStackView(arrangedSubviews: [headerTitle, lockIcon]))

    private lazy var headerView: UIStackView = {
        $0.axis = .vertical
        $0.alignment = .center
        return $0
    }(UIStackView(arrangedSubviews: [titleRow, headerStatus]))

    override func viewDidLoad() {
        super.viewDidLoad()

        title = presenter.title
        showMessageTimestampOnSwipeLeft = true

        //MARK: Шапка своя у всех диалогов — ради замка. Присутствие при этом
        // остаётся только у переписки на двоих: присутствие группы — это присутствие
        // нескольких человек, и одной строкой оно не выражается.
        navigationItem.titleView = headerView

        reloadTitle()

        //MARK: Кнопка только в группе. Диалог на двоих третьим не дополняется: его
        // id — пара uid по алфавиту, и чат из «Контактов» всегда попадает именно в
        // него. Дописав туда третьего, мы получили бы группу, в которую эти двое
        // проваливаются каждый раз, когда просто хотят написать друг другу.
        if presenter.isGroup {
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "person.2"),
                                                                style: .plain,
                                                                target: self,
                                                                action: #selector(showMembers))
        }

        settingMessanger()
    }

    //MARK: Отметка прочтения привязана к появлению и уходу экрана, а не к открытию чата:
    // под ним может лежать «Участники», и всё это время переписку не видно.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        presenter.screenBecameVisible()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        presenter.screenWentAway()
    }

    @objc private func showMembers() {
        let members = Builder.getChatMembersView(chat: presenter.chat)
        navigationController?.pushViewController(members, animated: true)
    }

    private func settingMessanger() {
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
        messageInputBar.delegate = self

        messagesCollectionView.backgroundColor = .bgMain
        view.backgroundColor = .bgMain

        settingInputBar()
    }

    //MARK: Панель ввода из MessageKit по умолчанию белая — на тёмном приложении она
    // выглядела чужой заплаткой.
    //
    //MARK: Фон был `tabBar`, чтобы панель читалась с таб-баром как одна поверхность.
    // Теперь он равен фону переписки, а отделяет её волосяная линия: панель принадлежит
    // ленте, а не нижней рамке экрана, и собственной плашкой она эту ленту обрезала.
    private func settingInputBar() {
        messageInputBar.backgroundView.backgroundColor = .bgMain
        messageInputBar.separatorLine.backgroundColor = .hairline
        messageInputBar.padding = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)

        //MARK: Само поле повторяет текстовые поля авторизации: поднятый фон, светлый
        // текст, приглушённый плейсхолдер, скругление 15 — см. Helpers/TextField.
        //
        //MARK: Чёрный фон поля ушёл вместе с ним. Чёрное на тёмно-синем — это провал,
        // а не поверхность: поле выглядело дырой в экране. «Поднятое» светлее фона, и
        // поле читается как то, на чём пишут.
        messageInputBar.inputTextView.backgroundColor = .raised
        messageInputBar.inputTextView.textColor = .ink
        messageInputBar.inputTextView.tintColor = .accent
        messageInputBar.inputTextView.font = .systemFont(ofSize: 16)
        messageInputBar.inputTextView.keyboardAppearance = .dark
        messageInputBar.inputTextView.placeholder = "Сообщение"
        messageInputBar.inputTextView.placeholderTextColor = .inkDim
        messageInputBar.inputTextView.layer.cornerRadius = 15
        messageInputBar.inputTextView.layer.masksToBounds = true
        messageInputBar.inputTextView.textContainerInset = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        messageInputBar.inputTextView.placeholderLabelInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)

        //MARK: Отправка — иконкой, как остальные действия в приложении
        // (`message`, `square.and.pencil`), а не английским словом Send посреди
        // русского интерфейса.
        messageInputBar.sendButton.title = nil
        messageInputBar.sendButton.image = UIImage(systemName: "arrow.up.circle.fill")
        messageInputBar.sendButton.imageView?.contentMode = .scaleAspectFit
        messageInputBar.sendButton.setSize(CGSize(width: 36, height: 36), animated: false)
        messageInputBar.sendButton.onEnabled { $0.tintColor = .accent }
        messageInputBar.sendButton.onDisabled { $0.tintColor = .inkDim }

        //MARK: Хуки срабатывают только на смену состояния, а кнопка создаётся уже
        // выключенной — до первого введённого символа она осталась бы с дефолтным
        // цветом. Красим по текущему состоянию.
        messageInputBar.sendButton.tintColor = messageInputBar.sendButton.isEnabled ? .accent : .inkDim

        messageInputBar.setLeftStackViewWidthConstant(to: 40, animated: false)
        messageInputBar.setStackViewItems([attachButton], forStack: .left, animated: false)

        //MARK: Кнопка отправки уже стоит в правой стопке, поэтому её приходится
        // перечислить заново: `setStackViewItems` задаёт состав целиком, а не дописывает.
        messageInputBar.setRightStackViewWidthConstant(to: 80, animated: false)
        messageInputBar.setStackViewItems([micButton, messageInputBar.sendButton], forStack: .right, animated: false)

        messageInputBar.addSubview(statusLabel)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: messageInputBar.inputTextView.leadingAnchor, constant: 16),
            statusLabel.centerYAnchor.constraint(equalTo: messageInputBar.inputTextView.centerYAnchor)
        ])
    }

    //MARK: Подпись занимает место поля ввода, а не встаёт рядом: панель и без того тесная,
    // а печатать во время записи или поиска всё равно не выйдет.
    private func showStatus(_ text: String, color: UIColor) {
        //MARK: Всякий новый статус отменяет подсказку: иначе её таймер, дотикав,
        // погасил бы уже чужую подпись — например, идущую запись.
        hintTimer?.invalidate()
        hintTimer = nil

        statusLabel.text = text
        statusLabel.textColor = color
        statusLabel.isHidden = false

        messageInputBar.inputTextView.isHidden = true
    }

    private func hideStatus() {
        hintTimer?.invalidate()
        hintTimer = nil

        statusLabel.isHidden = true
        messageInputBar.inputTextView.isHidden = false
    }

    //MARK: Подсказка, в отличие от записи и поиска геопозиции, не состояние, а ответ
    // на только что случившееся — поэтому уходит сама, без второго события.
    private func showHint(_ text: String) {
        showStatus(text, color: .inkDim)

        hintTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { [weak self] _ in
            self?.hideStatus()
        }
    }

    deinit {
        recordingTimer?.invalidate()
        hintTimer?.invalidate()
    }

    @objc private func handleMic(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            presenter.startRecording()
        case .ended:
            presenter.finishRecording()
        case .cancelled, .failed:
            presenter.cancelRecording()
        default:
            break
        }
    }

    func recordingStarted() {
        micButton.tintColor = .systemRed

        updateRecordingLabel()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.updateRecordingLabel()
        }
    }

    func recordingStopped() {
        recordingTimer?.invalidate()
        recordingTimer = nil

        hideStatus()
        micButton.tintColor = .accent
    }

    //MARK: Первое удержание уходит на системное окно с вопросом про микрофон, и
    // записи от него не остаётся. Раньше на этом всё и заканчивалось — кнопка
    // выглядела сломанной; теперь панель прямо говорит, что делать дальше.
    func microphoneGranted() {
        showHint("Микрофон разрешён — удерживайте, чтобы записать")
    }

    //MARK: Нас удалили из группы. Слушатели уже получили отказ и сняты, так что экран
    // всё равно замер: новых сообщений не будет, отправленное не дойдёт. Показываем
    // это словами и уводим к списку чатов — туда же, куда уводит выход по своей воле.
    //
    // Алерт показываем с верхнего экрана: удалить могли и в тот момент, когда человек
    // смотрит «Участников», а он открыт поверх переписки.
    func accessLost() {
        let top = navigationController?.topViewController ?? self

        top.showAlert(title: "Вас удалили из группы",
                      message: "Её переписка вам больше не видна.") { [weak self] in
            self?.navigationController?.popToRootViewController(animated: true)
        }
    }

    //MARK: Диалог стёрли — и не у нас одних. Уходим тем же путём, что и при удалении из
    // группы: алерт с верхнего экрана (поверх переписки могут быть открыты «Участники»)
    // и возврат к списку чатов.
    func chatDeleted() {
        let top = navigationController?.topViewController ?? self

        top.showAlert(title: presenter.isGroup ? "Группа удалена" : "Диалог удалён",
                      message: presenter.isGroup
                        ? "Переписка стёрта у всех участников."
                        : "Переписка стёрта у обоих.") { [weak self] in
            self?.navigationController?.popToRootViewController(animated: true)
        }
    }

    // MARK: - Поиск геопозиции

    func locationSearchStarted() {
        showStatus("◌ Определяем геопозицию…", color: .inkDim)
        attachButton.isEnabled = false
    }

    func locationSearchStopped() {
        hideStatus()
        attachButton.isEnabled = true
    }

    //MARK: Отправку приблизительной точки подтверждают явно. Отказ от точности —
    // осознанный выбор в настройках, но собеседник его не увидит: на карте будет обычная
    // метка, просто не там, где человек стоит.
    func confirmApproximateLocation(onSend: @escaping () -> Void) {
        showConfirm(title: "Точность ограничена",
                    message: "Для приложения включена приблизительная геопозиция, поэтому метка может уехать на километр от вашего места. Точность включается в Настройках, в разделе приложения.",
                    action: "Отправить приблизительно",
                    onConfirm: onSend)
    }

    //MARK: Показываем, сколько осталось, а не сколько записано: потолок жёсткий, и
    // упереться в него посреди фразы неприятнее, чем видеть обратный отсчёт.
    private func updateRecordingLabel() {
        let left = max(0, VoiceRecorder.maxDuration - presenter.recordingTime)

        showStatus("● Запись · осталось " + VoicePlayer.formatted(left), color: .systemRed)
    }

    func reloadCollection() {
        messagesCollectionView.reloadData()

        guard !presenter.messages.isEmpty else { return }
        messagesCollectionView.scrollToLastItem(animated: false)
    }

    //MARK: Перерисовка без прокрутки к последнему сообщению — в отличие от
    // `reloadCollection`. Аватары приезжают через секунду после открытия чата, и
    // утаскивать человека вниз из-за картинки, которую он не просил, незачем.
    func reloadAvatars() {
        messagesCollectionView.reloadData()
    }

    //MARK: Название группы — это её состав, поэтому оно меняется вместе с ним. Этим же
    // методом обновляется присутствие собеседника: обе строки шапки живут вместе.
    func reloadTitle() {
        title = presenter.title
        headerTitle.text = presenter.title
        headerStatus.text = presenter.status
        headerStatus.isHidden = presenter.status.isEmpty

        //MARK: Замок обновляется вместе с шапкой, а не выставляется один раз при её
        // создании: ключ диалога может приехать при открытом экране — например, когда
        // создатель дозапечатывает его тому, кто раньше не публиковал открытый ключ.
        lockIcon.isHidden = !presenter.chat.isEncrypted
    }

    func showError(_ message: String) {
        showErrorAlert(message)
    }

    // MARK: - Фото

    //MARK: `PHPickerViewController` работает в чужом процессе и отдаёт только выбранный
    // снимок, поэтому доступа к библиотеке он не просит вовсе — ни разрешения, ни строки
    // в Info.plist. Старый `UIImagePickerController` потребовал бы и того и другого,
    // а взамен не дал бы ничего.
    private func pickPhoto() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self

        present(picker, animated: true)
    }

    //MARK: Перерисовываем ровно то сообщение, чьё фото приехало. Индекс ищем заново по
    // id: пока снимок качался, переписка могла пополниться, и запомненный путь указывал
    // бы уже на чужую ячейку.
    private func reloadPhoto(_ messageId: String) {
        guard let section = presenter.messages.firstIndex(where: { $0.messageId == messageId }) else { return }

        messagesCollectionView.reloadItems(at: [IndexPath(item: 0, section: section)])
    }
}

extension MessangerView: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, err in
            //MARK: Провайдер отвечает не с главного потока, а дальше по цепочке идут и
            // алерт, и работа с интерфейсом.
            DispatchQueue.main.async {
                guard let image = object as? UIImage else {
                    self?.showError(err?.localizedDescription ?? "Не удалось прочитать фото")
                    return
                }

                self?.presenter.sendPhoto(image)
            }
        }
    }
}

extension MessangerView: MessageCellDelegate {

    //MARK: Звук тянется из базы только здесь, по нажатию. Ячейка к этому моменту уже
    // нарисована — ей хватало длительности из самого сообщения.
    func didTapPlayButton(in cell: AudioMessageCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else { return }

        let message = presenter.messages[indexPath.section]

        presenter.playVoice(messageId: message.messageId) { url in
            VoicePlayer.shared.toggle(url: url, messageId: message.messageId, cell: cell)
        }
    }

    //MARK: Во весь экран открываем только то, что уже расшифровано и лежит в памяти.
    // Пузырь с замком нажатие игнорирует: показывать нечего, а лезть за снимком второй
    // раз незачем — не открылся он не из-за связи.
    //MARK: Карта в пузыре — картинка, по ней не проложить маршрут и не рассмотреть
    // соседнюю улицу. Поэтому нажатие уводит в «Карты»: там точка и оказывается нужна.
    func didTapMessage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell),
              case .location(let place) = presenter.messages[indexPath.section].kind else { return }

        let item = MKMapItem(placemark: MKPlacemark(coordinate: place.location.coordinate))
        item.name = MessangerManager.locationPreview

        item.openInMaps()
    }

    func didTapImage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else { return }

        let message = presenter.messages[indexPath.section]

        guard message.isPhoto, let image = PhotoCache.shared.image(for: message.messageId) else { return }

        present(PhotoViewerController(image: image), animated: true)
    }
}

extension MessangerView: MessagesDataSource {

    var currentSender: any SenderType {
        presenter.selfSender
    }

    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        presenter.messages[indexPath.section]
    }

    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        presenter.messages.count
    }
}

extension MessangerView: MessagesDisplayDelegate, MessagesLayoutDelegate {

    //MARK: Имя отправителя нужно только в группе и только над чужими сообщениями:
    // в диалоге на двоих сторона бабла и аватар уже говорят, кто написал, а свои
    // сообщения подписывать незачем в любом случае.
    func messageTopLabelHeight(for message: any MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        showsSenderName(for: message) ? 18 : 0
    }

    func messageTopLabelAttributedText(for message: any MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        guard showsSenderName(for: message) else { return nil }

        return NSAttributedString(string: message.sender.displayName, attributes: [
            .font: UIFont.systemFont(ofSize: 13),
            .foregroundColor: UIColor.inkDim
        ])
    }

    private func showsSenderName(for message: any MessageType) -> Bool {
        presenter.isGroup && !isFromSelf(message)
    }

    //MARK: Высота от низа бабла до времени
    func messageBottomLabelHeight(for message: any MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        20
    }

    func backgroundColor(for message: any MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        //MARK: Оба бабла весят одинаково. Чужой был темнее фона и почти сливался с ним,
        // свой — насыщенный системный синий: разговор выглядел монологом, где слышно
        // только себя. Теперь чужой светлее фона, а свой приглушён.
        isFromSelf(message) ? .ownBubble : .raised
    }

    func textColor(for message: any MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        .ink
    }

    //MARK: Галочки приписываются к времени, а не занимают свою строку: под баблом уже
    // отведено место, и вторая метка встаёт в него без единой правки в вёрстке.
    //
    // Одна галочка — «ушло в базу», две — «прочитано». Разделять «доставлено» и
    // «отправлено» тут нечем и незачем: записалось в Firestore — значит доставлено всем,
    // кто откроет чат.
    func messageBottomLabelAttributedText(for message: any MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        let time = NSMutableAttributedString(
            string: message.sentDate.formatted(date: .omitted, time: .shortened),
            attributes: [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.inkDim
            ])

        //MARK: Только на своих. Чужому сообщению «прочитано» ничего не сообщает — я его
        // и так вижу, — а место под баблом занимает.
        guard isFromSelf(message), let own = message as? Message else { return time }

        let read = presenter.isRead(own)

        time.append(NSAttributedString(string: read ? " ✓✓" : " ✓", attributes: [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: read ? UIColor.accent : UIColor.inkDim
        ]))

        return time
    }

    //MARK: Ячейки переиспользуются, поэтому играющую надо узнавать по сообщению, а не
    // по самой ячейке: без этого прогресс с проигрываемого голосового всплывал бы на
    // чужом при прокрутке.
    func configureAudioCell(_ cell: AudioMessageCell, message: MessageType) {
        cell.playButton.isSelected = VoicePlayer.shared.playingMessageId == message.messageId
    }

    //MARK: Единственное место, где у фото появляется картинка. Ячейка успевает
    // нарисоваться раньше: размеры пузыря пришли в самом сообщении, а байты тянутся
    // отсюда — когда ячейка показалась на экране, а не при открытии чата. В переписке с
    // полусотней снимков разница между «скачать увиденное» и «скачать всё» существенная.
    func configureMediaMessageImageView(_ imageView: UIImageView, for message: any MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        let id = message.messageId

        if let cached = PhotoCache.shared.image(for: id) {
            imageView.image = cached
            return
        }

        guard !failedPhotos.contains(id) else {
            imageView.image = Photo.locked
            return
        }

        guard !loadingPhotos.contains(id) else { return }

        loadingPhotos.insert(id)

        presenter.loadPhoto(messageId: id) { [weak self] image in
            guard let self else { return }

            self.loadingPhotos.remove(id)

            if image == nil {
                self.failedPhotos.insert(id)
            }

            //MARK: Готовую картинку в `imageView` отсюда не кладём: пока снимок ехал,
            // ячейку могли переиспользовать под другое сообщение. Перерисовка ячейки
            // возьмёт фото из кэша сама — тем же путём, что и в первой строке метода.
            self.reloadPhoto(id)
        }
    }

    //MARK: Аватар, а если его нет — первая буква имени, как и было. `set(avatar:)`
    // сам выбирает одно из двух и, что важнее, перерисовывает картинку при
    // переиспользовании ячейки: без него фото уехавшего вверх сообщения осталось бы
    // висеть на чужом.
    func configureAvatarView(_ avatarView: AvatarView, for message: any MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        let initials = message.sender.displayName.first?.uppercased() ?? "?"
        let image = presenter.avatar(for: message.sender.senderId)

        avatarView.backgroundColor = isFromSelf(message) ? .ownBubble : .raised
        avatarView.set(avatar: Avatar(image: image, initials: initials))
    }

    private func isFromSelf(_ message: any MessageType) -> Bool {
        message.sender.senderId == presenter.selfSender.senderId
    }
}

extension MessangerView: InputBarAccessoryViewDelegate {

    //MARK: Поле очищается только если сообщение приняли к отправке. Иначе набранное
    // пропадало бы вместе с неудачей — а человеку его перенабирать.
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard presenter.sendMessage(text: text) else { return }

        inputBar.inputTextView.text = ""
    }
}
