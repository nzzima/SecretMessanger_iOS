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
    
    lazy var signOutButton: UIBarButtonItem = UIBarButtonItem(image: .actions, style: .done, target: self, action: #selector(signOut))
    
    let textAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
    
    lazy var tableView: UITableView = {
        $0.register(UINib(nibName: "UserCellTableViewCell", bundle: nil), forCellReuseIdentifier: UserCellTableViewCell.reuseIdentifier)
        $0.dataSource = self
        $0.backgroundColor = .bgMain
        $0.delegate = self
        $0.separatorStyle = .none
        return $0
    }(UITableView(frame: view.bounds))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .bgMain
        navigationItem.title = "Контакты"
        navigationController?.navigationBar.titleTextAttributes = textAttributes
        navigationItem.rightBarButtonItem = signOutButton
        view.addSubview(tableView)
    }
    
    @objc func signOut() {
        FirebaseManager.shared.signOut()
    }
    
    func reloadTable() {
        tableView.reloadData()
    }
}

extension UserListView: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        //guard let uid = FirebaseManager.shared.getUser()?.uid else { return }
        
        let profile = Builder.getUserProfileView()
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
