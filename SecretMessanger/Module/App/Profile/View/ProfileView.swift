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
    //MARK: Имя и заметка ушли из таблицы наверх, к аватару: это то, чем человек
    // представляется, а не поле анкеты. В карточке остались логин и имя — то, что
    // читают как справку.
    //
    //MARK: Идентификатор уехал вниз отдельной секцией и стал моноширинным. Раньше он
    // стоял **первой** строкой, то есть на месте заголовка — а это двадцативосьмизначная
    // техническая строка, которую не читают вовсе и не показывают никому.
    private var rows: [(title: String, value: String)] {
        guard let user = presenter.activeUser else { return [] }

        return [
            ("Логин", user.login),
            ("Имя", user.name)
        ]
    }

    private var identifier: String { presenter.activeUser?.id ?? "" }

    private let nameLabel: UILabel = {
        $0.font = .systemFont(ofSize: 21, weight: .semibold)
        $0.textColor = .ink
        $0.textAlignment = .center
        $0.translatesAutoresizingMaskIntoConstraints = false
        return $0
    }(UILabel())

    //MARK: Заметка под именем, а не строкой в таблице: это то, что человек написал о
    // себе сам, и читается оно вместе с именем, а не наравне с логином.
    private let noteLabel: UILabel = {
        $0.font = .systemFont(ofSize: 14)
        $0.textColor = .inkDim
        $0.textAlignment = .center
        $0.numberOfLines = 0
        $0.translatesAutoresizingMaskIntoConstraints = false
        return $0
    }(UILabel())

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
        $0.tintColor = .ink
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
        view.addSubviews(imageView, nameLabel, noteLabel, tableView)

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

        nameLabel.text = presenter.activeUser?.name
        noteLabel.text = presenter.activeUser?.someInfo
        noteLabel.isHidden = presenter.activeUser?.someInfo.isEmpty ?? true

        tableView.reloadData()
    }

    private func setConstraints() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.widthAnchor.constraint(equalToConstant: AvatarImageView.profileDiameter),
            imageView.heightAnchor.constraint(equalToConstant: AvatarImageView.profileDiameter),

            nameLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 16),
            nameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            nameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            noteLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 3),
            noteLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            noteLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            //MARK: Таблица тянется до низа экрана, а не занимает половину его высоты.
            // Доля от высоты подгонялась под четыре строки; их осталось две плюс
            // идентификатор, и та же доля оставила бы под ними пустоту.
            tableView.topAnchor.constraint(equalTo: noteLabel.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

extension ProfileView: UITableViewDataSource {

    //MARK: Две секции — две карточки: справка о себе и техническая строка под ней.
    // В одной они стояли бы наравне, а они не наравне.
    func numberOfSections(in tableView: UITableView) -> Int {
        presenter.activeUser == nil ? 0 : 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? rows.count : 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)

        guard indexPath.section == 0 else {
            cell.configureField(title: "Идентификатор", value: identifier, mono: true)

            return cell
        }

        let row = rows[indexPath.row]

        cell.configureField(title: row.title, value: row.value)

        return cell
    }
}

extension ProfileView: UITableViewDelegate {
    
}
