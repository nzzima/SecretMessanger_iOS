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

    let textAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]

    lazy var tableView: UITableView = {
        $0.register(ConversationTableViewCell.self, forCellReuseIdentifier: ConversationTableViewCell.reuseIdentifier)
        $0.dataSource = self
        $0.delegate = self
        $0.backgroundColor = .bgMain
        $0.separatorStyle = .none
        return $0
    }(UITableView(frame: view.bounds))

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
        navigationController?.navigationBar.titleTextAttributes = textAttributes

        view.addSubviews(tableView, emptyLabel)

        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
    }

    func reloadTable() {
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
        let messanger = Builder.getMessangerView(chatUser: presenter.chatUser(at: indexPath.row))
        navigationController?.pushViewController(messanger, animated: true)
    }
}
