//
//  ChatMembersView.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 10.08.2026.
//

import UIKit

protocol ChatMembersViewProtocol: AnyObject {
    func reloadTable()
    func left()
    func showError(_ message: String)
}

class ChatMembersView: UIViewController, ChatMembersViewProtocol {

    var presenter: ChatMembersViewPresenterProtocol!

    //MARK: Про `frame: view.bounds` в lazy-свойстве — см. подробный комментарий в
    // MessageListView: он приводил к созданию двух таблиц, и список переставал
    // обновляться после первой отрисовки.
    private lazy var tableView: UITableView = {
        $0.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        $0.dataSource = self
        $0.delegate = self
        $0.backgroundColor = .bgMain
        $0.separatorColor = .hairline
        $0.translatesAutoresizingMaskIntoConstraints = false
        return $0
    }(UITableView())

    private lazy var addButton = UIBarButtonItem(image: UIImage(systemName: "person.badge.plus"),
                                                 style: .plain,
                                                 target: self,
                                                 action: #selector(addMembers))

    private lazy var leaveButton: UIButton = {
        $0.setTitle("Выйти из группы", for: .normal)
        $0.setTitleColor(.red, for: .normal)
        $0.titleLabel?.font = .systemFont(ofSize: 17)
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.addTarget(self, action: #selector(leaveGroup), for: .touchUpInside)
        return $0
    }(UIButton())

    //MARK: Создателю выход закрыт, и вместо спрятанной кнопки экран говорит почему —
    // иначе это читалось бы как недоделка.
    private lazy var ownerNote: UILabel = {
        $0.text = "Вы создатель группы и не можете из неё выйти"
        $0.textColor = .gray
        $0.font = .systemFont(ofSize: 14)
        $0.numberOfLines = 0
        $0.textAlignment = .center
        $0.translatesAutoresizingMaskIntoConstraints = false
        return $0
    }(UILabel())

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .bgMain
        navigationItem.title = "Участники"

        //MARK: Кнопка только у создателя. Остальным экран остаётся как справка —
        // кто вообще в группе; менять состав им не даст и правило Firestore.
        if presenter.canManage {
            navigationItem.rightBarButtonItem = addButton
        }

        let footer: UIView = presenter.canLeave ? leaveButton : ownerNote
        view.addSubviews(tableView, footer)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            footer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            footer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            footer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30)
        ])

        reloadTable()
    }

    @objc private func addMembers() {
        let picker = Builder.getAddMembersView(excluded: presenter.excludedIds) { [weak self] contacts in
            self?.presenter.add(contacts: contacts)
        }

        navigationController?.pushViewController(picker, animated: true)
    }

    @objc private func leaveGroup() {
        let alert = UIAlertController(title: "Выйти из группы?",
                                      message: "Вы перестанете видеть её переписку. Вернуть вас сможет только создатель.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Выйти", style: .destructive) { [weak self] _ in
            self?.presenter.leave()
        })

        present(alert, animated: true)
    }

    func reloadTable() {
        guard isViewLoaded else { return }

        tableView.reloadData()
    }

    //MARK: Возвращаемся сразу к списку чатов, а не на экран переписки: из группы мы
    // вышли, и её слушатели уже получают отказ по правам.
    func left() {
        navigationController?.popToRootViewController(animated: true)
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
