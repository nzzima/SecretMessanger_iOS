//
//  UserProfileView.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 21.02.2025.
//

import Foundation
import UIKit

protocol UserProfileViewProtocol: AnyObject {
    func reloadProfile()
    func reloadAvatar()
    func showError(_ message: String)
}

class UserProfileView: UIViewController, UserProfileViewProtocol {

    var presenter: UserProfileViewPresenterProtocol!

    //MARK: Только публичные поля. Почта и идентификатор сюда не выносятся —
    // см. комментарий в ProfileInfo.
    private var rows: [(title: String, value: String)] {
        guard let profile = presenter.profile else { return [] }

        return [
            ("Логин", profile.login),
            ("Имя", profile.name),
            ("Заметка", profile.someInfo)
        ]
    }

    lazy var imageView = AvatarImageView.profile()

    lazy var rigthBarButton: UIButton = {
        $0.setImage(UIImage(systemName: "message"), for: .normal)
        $0.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        $0.imageView?.contentMode = .scaleAspectFit
        $0.addTarget(self, action: #selector(goToMessanger(_:)), for: .touchUpInside)
        return $0
    }(UIButton())

    //MARK: Про `frame: view.bounds` в lazy-свойстве — см. подробный комментарий в
    // MessageListView: он приводил к созданию двух таблиц, и экран переставал
    // обновляться после первой отрисовки.
    lazy var tableView: UITableView = {
        $0.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        $0.dataSource = self
        $0.delegate = self
        $0.backgroundColor = .bgMain
        $0.tintColor = .white
        $0.separatorColor = .darkGray
        $0.alwaysBounceVertical = false
        $0.translatesAutoresizingMaskIntoConstraints = false
        return $0
    }(UITableView(frame: .zero, style: .insetGrouped))

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .bgMain
        navigationItem.title = presenter.title
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: rigthBarButton)

        view.addSubviews(imageView, tableView)

        setConstraints()

        //MARK: Профиль мог прийти до загрузки экрана — показываем то, что уже есть.
        reloadProfile()
        reloadAvatar()
    }

    func reloadAvatar() {
        guard isViewLoaded else { return }

        imageView.show(presenter.avatar)
    }

    @objc func goToMessanger(_ sender: UIButton) {
        guard let chat = presenter.chat else { return }

        let messanger = Builder.getMessangerView(chat: chat)
        navigationController?.pushViewController(messanger, animated: true)
    }

    func reloadProfile() {
        //MARK: Без этой проверки первый же снапшот, пришедший до загрузки экрана,
        // тянул бы view из памяти раньше времени. Всё, что накопилось, покажет
        // `viewDidLoad` — заголовок он ставит сам, тем же `presenter.title`.
        guard isViewLoaded else { return }

        navigationItem.title = presenter.title
        tableView.reloadData()
    }

    func showError(_ message: String) {
        showErrorAlert(message)
    }

    private func setConstraints() {
        imageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.widthAnchor.constraint(equalToConstant: AvatarImageView.profileDiameter),
            imageView.heightAnchor.constraint(equalToConstant: AvatarImageView.profileDiameter),

            tableView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 30),
            tableView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tableView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            tableView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.5)
        ])
    }
}

extension UserProfileView: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let row = rows[indexPath.item]

        cell.backgroundColor = .black
        cell.selectionStyle = .none

        var config = cell.defaultContentConfiguration()

        config.text = row.title
        config.secondaryText = row.value
        config.secondaryTextProperties.color = .white
        config.secondaryTextProperties.font = .systemFont(ofSize: 18)
        config.textProperties.color = .gray
        config.textProperties.font = .systemFont(ofSize: 14)

        cell.contentConfiguration = config

        return cell
    }
}

extension UserProfileView: UITableViewDelegate {

}
