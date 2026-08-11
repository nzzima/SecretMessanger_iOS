//
//  LocationProvider.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 11.08.2026.
//

import CoreLocation

enum LocationError: LocalizedError {
    case denied
    case failed

    var errorDescription: String? {
        switch self {
        case .denied:
            return "Доступ к геопозиции запрещён. Включить его можно в Настройках, в разделе приложения."
        case .failed:
            return "Не удалось определить местоположение"
        }
    }
}

//MARK: Однократный запрос координат — ровно то, что нужно, чтобы отправить точку.
//
// Не `startUpdatingLocation()`: слежение за перемещением нужно живой геопозиции, которой
// здесь нет и которая тянет за собой совсем другой разговор — когда её выключать, сколько
// она живёт и что видит собеседник после. Мы отправляем снимок «я сейчас здесь».
//
// Разрешение спрашивается в момент, когда человек выбрал «Геопозиция» в меню вложений, а
// не при открытии чата: система показывает своё окно ровно тогда, когда понятно, зачем
// она спрашивает.
final class LocationProvider: NSObject {

    private let manager = CLLocationManager()
    private var completion: ((Result<CLLocation, Error>) -> Void)?

    override init() {
        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func current(completion: @escaping (Result<CLLocation, Error>) -> Void) {
        //MARK: Второй запрос поверх незавершённого игнорируем: `requestLocation()`
        // отвечает один раз, и перезаписанный колбэк остался бы висеть навсегда.
        guard self.completion == nil else { return }

        self.completion = completion

        switch manager.authorizationStatus {
        case .notDetermined:
            //MARK: Ответ придёт в делегат, там и продолжим — синхронного ответа у
            // системного окна нет.
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            finish(.failure(LocationError.denied))
        }
    }

    private func finish(_ result: Result<CLLocation, Error>) {
        let completion = self.completion
        self.completion = nil

        completion?(result)
    }
}

extension LocationProvider: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        //MARK: Метод зовётся и при старте, когда никто ничего не просил, — отсюда
        // проверка на висящий запрос.
        guard completion != nil else { return }

        switch manager.authorizationStatus {
        case .notDetermined:
            break
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            finish(.failure(LocationError.denied))
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            finish(.failure(LocationError.failed))
            return
        }

        finish(.success(location))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(.failure(error))
    }
}
