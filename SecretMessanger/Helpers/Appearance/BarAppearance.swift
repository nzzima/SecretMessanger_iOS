//
//  BarAppearance.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 11.08.2026.
//

import UIKit

//MARK: Панели навигации и вкладок красятся здесь, один раз на всё приложение.
//
// До этого их не красил никто, и приложение выезжало на том, что **пустая панель
// прозрачна**: пока список пролистан в начало, сквозь неё виден тёмный экран, и
// казалось, что всё в порядке. Стоило прокрутить — под панель уезжало содержимое, iOS
// подставляла `standardAppearance`, а он по умолчанию светлый, и шапка с таб-баром
// белели посреди тёмного приложения.
//
// Отсюда три состояния, а не одно: `scrollEdge` — панель у края содержимого,
// `standard` — под панелью что-то проехало, `compact` — та же панель в альбомной
// ориентации. Все три должны быть одинаковыми, иначе цвет меняется от прокрутки.
enum BarAppearance {

    static func apply() {
        let navigation = UINavigationBarAppearance()

        //MARK: `configureWithOpaqueBackground()` ставит системную подложку с размытием,
        // и `backgroundColor` лёг бы поверх неё — цвет получился бы приблизительным.
        // Размытие поэтому снимаем явно: панель должна совпасть с экраном точь-в-точь.
        navigation.configureWithOpaqueBackground()
        navigation.backgroundEffect = nil
        navigation.backgroundColor = .bgMain
        navigation.shadowColor = .darkGray
        navigation.titleTextAttributes = [.foregroundColor: UIColor.white]

        //MARK: Заголовок раньше красили семь экранов, каждый у себя. Строка была одна и
        // та же, и любой новый экран про неё забывал бы — как забыли про сами панели.
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = navigation
        UINavigationBar.appearance().compactAppearance = navigation

        let tab = UITabBarAppearance()

        tab.configureWithOpaqueBackground()
        tab.backgroundEffect = nil
        tab.backgroundColor = .tabBar
        tab.shadowColor = .darkGray

        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }
}
