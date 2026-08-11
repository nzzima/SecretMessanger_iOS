//
//  Place.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 11.08.2026.
//

import UIKit
import MessageKit
import CoreLocation

//MARK: Точка на карте в том виде, в каком её показывает MessageKit: он сам заказывает
// снимок карты у `MKMapSnapshotter` и рисует его в пузыре, так что своей ячейки писать
// не пришлось.
//
// Байтов у геопозиции нет — есть две координаты, и они помещаются в само сообщение.
// Подколлекция, как у фото и голосовых, тут была бы обрядом: её заводили ради размера.
struct Place: LocationItem {

    var location: CLLocation
    var size: CGSize

    init(location: CLLocation) {
        self.location = location
        self.size = CGSize(width: 240, height: 160)
    }

    //MARK: Полезная нагрузка сообщения — «широта,долгота». Формат нарочно простейший:
    // это две цифры, которые шифруются целиком, и городить вокруг них JSON значило бы
    // отдать в базу лишние байты и разбирать их при каждом чтении.
    //
    // Шесть знаков после запятой — около десяти сантиметров, заведомо точнее всего, что
    // отдаёт телефон.
    init?(payload: String) {
        let parts = payload.split(separator: ",")

        guard parts.count == 2,
              let latitude = Double(parts[0]),
              let longitude = Double(parts[1]),
              CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: latitude, longitude: longitude)) else {
            return nil
        }

        self.init(location: CLLocation(latitude: latitude, longitude: longitude))
    }

    //MARK: `String(format:)` без локали печатает точку, а не запятую, — и это здесь не
    // придирка: с запятой в дробной части строка «широта,долгота» распалась бы на четыре
    // куска, а не на два.
    static func payload(for location: CLLocation) -> String {
        String(format: "%.6f,%.6f", location.coordinate.latitude, location.coordinate.longitude)
    }
}
