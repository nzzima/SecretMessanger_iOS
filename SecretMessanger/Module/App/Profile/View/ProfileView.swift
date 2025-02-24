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
    
    lazy var imageView: UIImageView = {
        $0.image = UIImage(named: "basicUserImage")
        $0.contentMode = .scaleAspectFill
        $0.clipsToBounds = true
        $0.layer.masksToBounds = true
        $0.layer.cornerRadius = 50
        return $0
    }(UIImageView())
    
    lazy var tableView: UITableView = {
        $0.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        $0.dataSource = self
        $0.backgroundColor = .bgMain
        $0.delegate = self
        $0.separatorColor = .darkGray
        $0.alwaysBounceVertical = false
        return $0
    }(UITableView(frame: view.bounds, style: .insetGrouped))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .bgMain
        navigationItem.title = "Профиль"
        navigationController?.navigationBar.titleTextAttributes = textAttributes
        view.addSubviews(imageView, tableView)
        
        setConstraints()
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
            imageView.widthAnchor.constraint(equalToConstant: 100),
            imageView.heightAnchor.constraint(equalToConstant: 100),
            
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
        
        //TODO: Изменить цвет текста в ячейке с черного(стандарт) на белый
        
        let tableItem = presenter.activeUser[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = tableItem.id
        
        cell.contentConfiguration = config
        
        return cell
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        60
    }
    
}

extension ProfileView: UITableViewDelegate {
    
}
