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
}

class ProfileView: UIViewController, ProfileViewProtocol {
    
    var presenter: ProfileViewPresenterProtocol!
    
    let textAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
    
    let titleInfoCell = ["Идентификатор", "Логин", "Имя", "Заметка"]
    
    lazy var imageView: UIImageView = {
        $0.image = UIImage(named: "basicUserImage")
        $0.contentMode = .scaleAspectFill
        $0.layer.borderWidth = 4
        $0.layer.borderColor = UIColor.gray.cgColor
        $0.clipsToBounds = true
        $0.layer.masksToBounds = true
        $0.layer.cornerRadius = 50
        return $0
    }(UIImageView())
    
    lazy var rigthBarButton: UIButton = {
        $0.setImage(UIImage(systemName: "square.and.pencil"), for: .normal)
        $0.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        $0.imageView?.contentMode = .scaleAspectFit
        $0.addTarget(self, action: #selector(goToEditProfile(_:)), for: .touchUpInside)
        return $0
    }(UIButton())
    
    lazy var tableView: UITableView = {
        $0.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        $0.dataSource = self
        $0.backgroundColor = .bgMain
        $0.delegate = self
        $0.tintColor = .white
        $0.separatorColor = .darkGray
        $0.alwaysBounceVertical = false
        return $0
    }(UITableView(frame: view.bounds, style: .insetGrouped))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .bgMain
        navigationItem.title = "Профиль"
        let itemRightBar = UIBarButtonItem(customView: rigthBarButton)
        navigationItem.rightBarButtonItem = itemRightBar
        navigationController?.navigationBar.titleTextAttributes = textAttributes
        view.addSubviews(imageView, tableView)
        
        setConstraints()
    }
    
    override func viewWillAppear(_ animated: Bool) { // Hide tabBar
        hidesBottomBarWhenPushed = true
    }
        
    override func viewDidDisappear(_ animated: Bool) { // Show tabBar
        hidesBottomBarWhenPushed = false
    }
    
    @objc func goToEditProfile(_ sender: UIBarButtonItem) {
        let editProfileVC = Builder.getEditProfileView()
        navigationController?.pushViewController(editProfileVC, animated: true)
    }
    
    func reloadTable() {
        tableView.reloadData()
    }
    
    private func setConstraints() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 120),
            imageView.heightAnchor.constraint(equalToConstant: 120),
            
            tableView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 30),
            tableView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tableView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            tableView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.5)
        ])
    }
}

extension ProfileView: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        presenter.activeUser.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        cell.backgroundColor = .black
        cell.selectionStyle = .none
        
        var config = cell.defaultContentConfiguration()
        
        config.text = titleInfoCell[indexPath.item]
        config.secondaryText = presenter.activeUser[indexPath.item]
        config.secondaryTextProperties.color = .white
        config.secondaryTextProperties.font = .systemFont(ofSize: 18)
        config.textProperties.color = .gray
        config.textProperties.font = .systemFont(ofSize: 14)
        
        cell.contentConfiguration = config
        
        return cell
    }
}

extension ProfileView: UITableViewDelegate {
    
}
