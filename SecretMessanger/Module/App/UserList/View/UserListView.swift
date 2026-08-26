//
//  UserListView.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 30.01.2025.
//

import Foundation
import UIKit
import FirebaseFirestore

protocol UserListViewProtocol: AnyObject {
    func reloadTable()
}

class UserListView: UIViewController, UserListViewProtocol {
    var presenter: UserListViewPresenterProtocol!
    
    //MARK: Про `frame: view.bounds` в lazy-свойстве — см. подробный комментарий в
    // MessageListView: он приводил к созданию двух таблиц, и список переставал
    // обновляться после первой отрисовки.
    lazy var tableView: UITableView = {
        $0.register(UserCellTableViewCell.self, forCellReuseIdentifier: UserCellTableViewCell.reuseIdentifier)
        $0.dataSource = self
        $0.backgroundColor = .bgMain
        $0.delegate = self

        //MARK: Волосяная линия вместо ничего. Раньше строки разделяла обводка вокруг
        // каждой — теперь одна линия между ними, и начинается она под текстом, а не
        // под аватаром: аватар к следующей строке не относится.
        $0.separatorStyle = .singleLine
        $0.separatorColor = .hairline
        $0.separatorInset = UIEdgeInsets(top: 0, left: 72, bottom: 0, right: 0)
        $0.translatesAutoresizingMaskIntoConstraints = false
        return $0
    }(UITableView())
    
    lazy var rigthBarButton: UIButton = {
        $0.setImage(UIImage(systemName: "rectangle.and.pencil.and.ellipsis"), for: .normal)
        $0.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        $0.imageView?.contentMode = .scaleAspectFit
        $0.addTarget(self, action: #selector(searchButton), for: .touchUpInside)
        return $0
    }(UIButton())
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .bgMain
        navigationItem.title = "Контакты"
        let itemRightBar = UIBarButtonItem(customView: rigthBarButton)
        navigationItem.rightBarButtonItem = itemRightBar
        view.addSubviews(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        //MARK: Юзеры могли прийти до загрузки экрана — показываем то, что уже есть.
        reloadTable()
    }

    @objc func searchButton() {
        navigationController?.pushViewController(Builder.getNewChatView(), animated: true)
    }

    func reloadTable() {
        guard isViewLoaded else { return }

        tableView.reloadData()
    }
}

extension UserListView: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let profile = Builder.getUserProfileView(chatUser: presenter.users[indexPath.row])
        navigationController?.pushViewController(profile, animated: true)
   }
}

extension UserListView: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        presenter.users.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: UserCellTableViewCell.reuseIdentifier, for: indexPath) as! UserCellTableViewCell
                
        cell.selectionStyle = .none
        
        let cellItem = presenter.users[indexPath.row]
        cell.configCell(cellItem,
                        presence: presenter.presenceText(cellItem.id),
                        isOnline: presenter.isOnline(cellItem.id))
        
        return cell
    }
        
    //MARK: 64 pt вместо 100. Строка стала ниже, а несёт больше: имя и присутствие
    // словами. Четыре контакта помещаются там, где помещалось три, и экран перестаёт
    // быть наполовину пустым при трёх зарегистрированных.
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 64
    }
}
