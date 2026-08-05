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
    
    let textAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
    
    lazy var tableView: UITableView = {
        $0.register(UINib(nibName: "UserCellTableViewCell", bundle: nil), forCellReuseIdentifier: UserCellTableViewCell.reuseIdentifier)
        $0.dataSource = self
        $0.backgroundColor = .bgMain
        $0.delegate = self
        $0.separatorStyle = .none
        return $0
    }(UITableView(frame: view.bounds))
    
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
        navigationController?.navigationBar.titleTextAttributes = textAttributes
        let itemRightBar = UIBarButtonItem(customView: rigthBarButton)
        navigationItem.rightBarButtonItem = itemRightBar
        view.addSubviews(tableView)
    }
    
    @objc func searchButton() {
        print("Start search")
    }
    
    func reloadTable() {
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
        cell.configCell(cellItem.login)
        
        return cell
    }
        
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
}
