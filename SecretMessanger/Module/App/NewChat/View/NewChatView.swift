//
//  NewChatView.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 07.08.2026.
//

import UIKit

protocol NewChatViewProtocol: AnyObject {
    func reloadTable()
}

class NewChatView: UIViewController, NewChatViewProtocol {

    var presenter: NewChatViewPresenterProtocol!

    let textAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]

    lazy var tableView: UITableView = {
        $0.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        $0.dataSource = self
        $0.delegate = self
        $0.backgroundColor = .bgMain
        $0.separatorColor = .darkGray
        $0.translatesAutoresizingMaskIntoConstraints = false
        return $0
    }(UITableView())

    private lazy var createButton: UIBarButtonItem = {
        let title = presenter.isAddingMembers ? "Добавить" : "Создать"
        let item = UIBarButtonItem(title: title, style: .done, target: self, action: #selector(createChat))
        item.isEnabled = false
        return item
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .bgMain
        navigationItem.title = presenter.isAddingMembers ? "Добавить в группу" : "Новый чат"
        navigationController?.navigationBar.titleTextAttributes = textAttributes
        navigationItem.rightBarButtonItem = createButton

        view.addSubviews(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        reloadTable()
    }

    @objc private func createChat() {
        //MARK: Добавление возвращает выбранных тому, кто экран открыл, — состав
        // правит презентер «Участников», у него на руках свежая шапка диалога.
        if presenter.isAddingMembers {
            presenter.addSelected()
            navigationController?.popViewController(animated: true)
            return
        }

        guard let chat = presenter.makeChat() else { return }

        let messanger = Builder.getMessangerView(chat: chat)

        //MARK: Экран выбора из стека убираем: возвращаться в него из переписки
        // некуда — чат уже создан.
        guard var stack = navigationController?.viewControllers else { return }
        stack.removeLast()
        stack.append(messanger)
        navigationController?.setViewControllers(stack, animated: true)
    }

    func reloadTable() {
        guard isViewLoaded else { return }

        tableView.reloadData()

        let count = presenter.selectedCount
        createButton.isEnabled = count > 0

        guard !presenter.isAddingMembers else { return }

        navigationItem.title = count > 1 ? "Новая группа" : "Новый чат"
    }
}

extension NewChatView: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        presenter.users.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)

        var config = cell.defaultContentConfiguration()
        config.text = presenter.users[indexPath.row].login
        config.textProperties.color = .white
        cell.contentConfiguration = config

        cell.backgroundColor = .bgMain
        cell.tintColor = .systemBlue
        cell.accessoryType = presenter.isSelected(at: indexPath.row) ? .checkmark : .none
        cell.selectionStyle = .none

        return cell
    }
}

extension NewChatView: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        presenter.toggleSelection(at: indexPath.row)
    }
}
