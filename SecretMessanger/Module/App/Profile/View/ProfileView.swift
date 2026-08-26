//
//  ProfileView.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 30.01.2025.
//

import Foundation
import UIKit

protocol ProfileViewProtocol: AnyObject {
    func reloadTable()
    func reloadAvatar()
}

class ProfileView: UIViewController, ProfileViewProtocol {
    
    var presenter: ProfileViewPresenterProtocol!

    //MARK: Подпись и значение стоят рядом, в одной строке кода. Раньше подписи лежали
    // здесь массивом, а значения приходили из менеджера другим массивом, и совпадали
    // они только порядком — договором, который ничто не проверяло.
    private var rows: [(title: String, value: String)] {
        guard let user = presenter.activeUser else { return [] }

        return [
            ("Идентификатор", user.id),
            ("Логин", user.login),
            ("Имя", user.name),
            ("Заметка", user.someInfo)
        ]
    }

    lazy var imageView = AvatarImageView.profile()
    
    lazy var rigthBarButton: UIButton = {
        $0.setImage(UIImage(systemName: "square.and.pencil"), for: .normal)
        $0.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        $0.imageView?.contentMode = .scaleAspectFit
        $0.addTarget(self, action: #selector(goToEditProfile(_:)), for: .touchUpInside)
        return $0
    }(UIButton())
    
    //MARK: Про `frame: view.bounds` в lazy-свойстве — см. подробный комментарий в
    // MessageListView: он приводил к созданию двух таблиц, и экран переставал
    // обновляться после первой отрисовки. Здесь дефект был не теоретическим:
    // слушатель профиля стартует при запуске приложения, а вкладка открывается
    // позже, так что первый снапшот регулярно приходил раньше `viewDidLoad`.
    lazy var tableView: UITableView = {
        $0.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        $0.dataSource = self
        $0.backgroundColor = .bgMain
        $0.delegate = self
        $0.tintColor = .white
        $0.separatorColor = .hairline
        $0.alwaysBounceVertical = false
        $0.translatesAutoresizingMaskIntoConstraints = false
        return $0
    }(UITableView(frame: .zero, style: .insetGrouped))

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .bgMain
        navigationItem.title = "Профиль"
        let itemRightBar = UIBarButtonItem(customView: rigthBarButton)
        navigationItem.rightBarButtonItem = itemRightBar
        view.addSubviews(imageView, tableView)

        setConstraints()

        //MARK: Профиль мог прийти до загрузки экрана — показываем то, что уже есть.
        reloadTable()
        reloadAvatar()
    }

    //MARK: Заглушка остаётся, пока аватара нет или он ещё едет. Своя картинка при этом
    // почти всегда приходит из кэша мгновенно — её положили туда при сохранении.
    func reloadAvatar() {
        guard isViewLoaded else { return }

        imageView.show(presenter.avatar)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        hidesBottomBarWhenPushed = true
    }
        
    override func viewDidDisappear(_ animated: Bool) {
        hidesBottomBarWhenPushed = false
    }
    
    @objc func goToEditProfile(_ sender: UIBarButtonItem) {
        let editProfileVC = Builder.getEditProfileView()
        navigationController?.pushViewController(editProfileVC, animated: true)
    }
    
    func reloadTable() {
        //MARK: Без этой проверки первый же снапшот, пришедший до загрузки экрана,
        // тянул бы view из памяти раньше времени. Всё, что накопилось, покажет
        // `viewDidLoad`.
        guard isViewLoaded else { return }

        tableView.reloadData()
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

extension ProfileView: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let row = rows[indexPath.row]

        cell.configureField(title: row.title, value: row.value)

        return cell
    }
}

extension ProfileView: UITableViewDelegate {
    
}
