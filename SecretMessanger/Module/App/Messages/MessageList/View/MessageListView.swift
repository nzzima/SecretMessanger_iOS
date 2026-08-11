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
        $0.separatorStyle = .none
        $0.translatesAutoresizingMaskIntoConstraints = false
        return $0
    }(UITableView())

    private let emptyLabel: UILabel = {
        $0.text = "Пока ни одного диалога.\nНачните переписку из «Контактов»."
        $0.textColor = .lightGray
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
}

extension MessageListView: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        presenter.conversations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ConversationTableViewCell.reuseIdentifier, for: indexPath) as! ConversationTableViewCell

        cell.configCell(presenter.conversations[indexPath.row])

        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        90
    }
}

extension MessageListView: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let messanger = Builder.getMessangerView(chat: presenter.chat(at: indexPath.row))
        navigationController?.pushViewController(messanger, animated: true)
    }
}
