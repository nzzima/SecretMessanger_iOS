//
//  ChatMembersView.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 10.08.2026.
//

import UIKit

protocol ChatMembersViewProtocol: AnyObject {
    func reloadTable()
    func showError(_ message: String)
}

class ChatMembersView: UIViewController, ChatMembersViewProtocol {

    var presenter: ChatMembersViewPresenterProtocol!

    private let textAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]

    //MARK: Про `frame: view.bounds` в lazy-свойстве — см. подробный комментарий в
    // MessageListView: он приводил к созданию двух таблиц, и список переставал
    // обновляться после первой отрисовки.
    private lazy var tableView: UITableView = {
        $0.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        $0.dataSource = self
        $0.delegate = self
        $0.backgroundColor = .bgMain
        $0.separatorColor = .darkGray
        $0.translatesAutoresizingMaskIntoConstraints = false
        return $0
    }(UITableView())

    private lazy var addButton = UIBarButtonItem(image: UIImage(systemName: "person.badge.plus"),
                                                 style: .plain,
                                                 target: self,
                                                 action: #selector(addMembers))

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .bgMain
        navigationItem.title = "Участники"
        navigationController?.navigationBar.titleTextAttributes = textAttributes

        //MARK: Кнопка только у создателя. Остальным экран остаётся как справка —
        // кто вообще в группе; менять состав им не даст и правило Firestore.
        if presenter.canManage {
            navigationItem.rightBarButtonItem = addButton
        }

        view.addSubviews(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        reloadTable()
    }

    @objc private func addMembers() {
        let picker = Builder.getAddMembersView(excluded: presenter.excludedIds) { [weak self] contacts in
            self?.presenter.add(contacts: contacts)
        }

        navigationController?.pushViewController(picker, animated: true)
    }

    func reloadTable() {
        guard isViewLoaded else { return }

        tableView.reloadData()
    }

    func showError(_ message: String) {
        showErrorAlert(message)
    }
}

extension ChatMembersView: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        presenter.members.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let member = presenter.members[indexPath.row]

        var config = cell.defaultContentConfiguration()
        config.text = member.isSelf ? member.login + " (вы)" : member.login
        config.textProperties.color = .white

        if member.isOwner {
            config.secondaryText = "создатель"
            config.secondaryTextProperties.color = .gray
            config.secondaryTextProperties.font = .systemFont(ofSize: 13)
        }

        cell.contentConfiguration = config
        cell.backgroundColor = .bgMain
        cell.selectionStyle = .none

        return cell
    }
}

extension ChatMembersView: UITableViewDelegate {

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard presenter.canRemove(at: indexPath.row) else { return nil }

        let login = presenter.members[indexPath.row].login

        let remove = UIContextualAction(style: .destructive, title: "Удалить") { [weak self] _, _, done in
            //MARK: Спрашиваем подтверждение: удаление участника видно всей группе и
            // откатывается только повторным добавлением.
            let alert = UIAlertController(title: "Удалить \(login)?",
                                          message: "Участник перестанет видеть группу и её переписку.",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Отмена", style: .cancel) { _ in done(false) })
            alert.addAction(UIAlertAction(title: "Удалить", style: .destructive) { _ in
                self?.presenter.remove(at: indexPath.row)
                done(true)
            })

            self?.present(alert, animated: true)
        }

        return UISwipeActionsConfiguration(actions: [remove])
    }
}
