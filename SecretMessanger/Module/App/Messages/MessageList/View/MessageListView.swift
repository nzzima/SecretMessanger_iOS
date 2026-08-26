//
//  MessageListView.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 31.01.2025.
//

import Foundation
import UIKit

protocol MessageListViewProtocol: AnyObject {
    func reloadTable()
    func showError(_ message: String)
}

class MessageListView: UIViewController, MessageListViewProtocol {

    var presenter: MessageListViewPresenterProtocol!

    //MARK: `UITableView(frame: view.bounds)` здесь стоять не должно: обращение к
    // `view.bounds` внутри инициализатора принудительно грузит view, а `viewDidLoad`
    // в этот момент снова обращается к `tableView`. Пока внешний инициализатор не
    // завершился, хранилище lazy-свойства пустое, поэтому создаётся вторая таблица:
    // на экран попадает она, а свойство остаётся с первой. Дальше `reloadData()`
    // уходит в таблицу, которой на экране нет, и список перестаёт обновляться —
    // новый диалог появлялся только после перезапуска приложения.
    lazy var tableView: UITableView = {
        $0.register(ConversationTableViewCell.self, forCellReuseIdentifier: ConversationTableViewCell.reuseIdentifier)
        $0.dataSource = self
        $0.delegate = self
        $0.backgroundColor = .bgMain

        //MARK: Волосяная линия вместо обводки вокруг каждой строки — см. «Контакты».
        $0.separatorStyle = .singleLine
        $0.separatorColor = .hairline
        $0.separatorInset = UIEdgeInsets(top: 0, left: 72, bottom: 0, right: 0)
        $0.translatesAutoresizingMaskIntoConstraints = false
        return $0
    }(UITableView())

    private let emptyLabel: UILabel = {
        $0.text = "Пока ни одного диалога.\nНачните переписку из «Контактов»."
        $0.textColor = .inkDim
        $0.font = .systemFont(ofSize: 16)
        $0.numberOfLines = 0
        $0.textAlignment = .center
        $0.translatesAutoresizingMaskIntoConstraints = false
        return $0
    }(UILabel())

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .bgMain
        navigationItem.title = "Чаты"

        view.addSubviews(tableView, emptyLabel)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])

        //MARK: Данные могли прийти до загрузки экрана — показываем то, что уже есть.
        reloadTable()
    }

    func reloadTable() {
        //MARK: Без этой проверки первый же снапшот, пришедший до загрузки экрана,
        // тянул бы view из памяти раньше времени. Всё, что накопилось, покажет
        // `viewDidLoad`.
        guard isViewLoaded else { return }

        tableView.reloadData()

        //MARK: Пустой список — не ошибка, но и не повод показывать голый экран:
        // до этой правки вкладка «Чаты» выглядела сломанной.
        emptyLabel.isHidden = !presenter.conversations.isEmpty
    }

    func showError(_ message: String) {
        showErrorAlert(message)
    }
}

extension MessageListView: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        presenter.conversations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ConversationTableViewCell.reuseIdentifier, for: indexPath) as! ConversationTableViewCell

        let conversation = presenter.conversations[indexPath.row]
        let version = conversation.companionId.map { presenter.avatarVersion(for: $0) } ?? 0

        cell.configCell(conversation, avatarVersion: version)

        return cell
    }

    //MARK: 72 pt вместо 90 — вслед за аватаром, ужавшимся до 44.
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        72
    }
}

extension MessageListView: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let messanger = Builder.getMessangerView(chat: presenter.chat(at: indexPath.row))
        navigationController?.pushViewController(messanger, animated: true)
    }

    //MARK: Свайп, а не кнопка в шапке диалога: удаление отсюда стирает переписку у всех
    // участников и не отменяется. Жест плюс подтверждение — ровно та цена, которую
    // такое действие должно стоить, и ровно то место, где его ищут.
    //
    // Строки без права на удаление свайпа не имеют вовсе: серую кнопку, которая
    // отказывает после нажатия, участник группы видел бы на каждой её строке.
    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard presenter.canDelete(at: indexPath.row) else { return nil }

        let delete = UIContextualAction(style: .destructive, title: "Удалить") { [weak self] _, _, done in
            //MARK: `false` — «действие не выполнено», и это здесь правда: строку мы не
            // убираем. Сказать `true` значило бы пообещать таблице удалённую строку,
            // которой нет, — и получить её обратно рывком, если человек передумает в
            // подтверждении. Настоящее исчезновение приносит слушатель, когда диалога
            // не станет в базе.
            done(false)

            self?.confirmDelete(at: indexPath.row)
        }

        return UISwipeActionsConfiguration(actions: [delete])
    }

    private func confirmDelete(at index: Int) {
        guard presenter.conversations.indices.contains(index) else { return }

        let isGroup = presenter.conversations[index].isGroup

        //MARK: В вопросе — что именно случится, а не «вы уверены». Уверенность тут
        // ничего не стоит, а «сотрётся у всех и навсегда» стоит.
        showConfirm(title: isGroup ? "Удалить группу?" : "Удалить диалог?",
                    message: isGroup
                        ? "Переписка и вложения сотрутся у всех участников. Вернуть их будет нельзя."
                        : "Переписка и вложения сотрутся у обоих. Вернуть их будет нельзя.",
                    action: "Удалить",
                    destructive: true) { [weak self] in
            self?.presenter.delete(at: index)
        }
    }
}
