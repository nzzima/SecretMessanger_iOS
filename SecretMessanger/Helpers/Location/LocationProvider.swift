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
            return "Не удалось определить местоположение. В помещении сигнал часто не ловится — попробуйте у окна или на улице."
        }
    }
}

//MARK: Однократный запрос координат — ровно то, что нужно, чтобы отправить точку.
//
// Не `startUpdatingLocation()`: слежение за перемещением нужно живой геопозиции, которой
// здесь нет и которая тянет за собой совсем другой разговор — когда её выключать, сколько
// она живёт и что видит собеседник после. Мы отправляем снимок «я сейчас здесь».
//
// Работа разбита на два шага намеренно. Доступ выясняется **до** того, как ловить
// спутники: если точность окажется приблизительной, спросить об этом человека надо
// раньше, чем он десять секунд смотрел на «определяем», а не после.
final class LocationProvider: NSObject {

    //MARK: Ключ из `NSLocationTemporaryUsageDescriptionDictionary` в Info.plist. Через
    // него система берёт объяснение, зачем разово понадобилась точность.
    private static let purposeKey = "ShareLocation"

    //MARK: Три попытки, потому что первый фикс в помещении срывается обычным порядком, и
    // одна неудача — это не ответ. Дальше уже честнее сказать, что не вышло.
    private static let attempts = 3
    private static let pause: TimeInterval = 1

    private let manager = CLLocationManager()

    private var access: ((Result<Bool, Error>) -> Void)?
    private var located: ((Result<CLLocation, Error>) -> Void)?
    private var attemptsLeft = 0

    override init() {
        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    // MARK: - Шаг первый: доступ

    //MARK: Отвечает, можно ли брать координаты, и полная ли будет точность. `false` — это
    // не отказ: человек разрешил доступ, но оставил приблизительную геопозицию, и точка
    // уедет на километры. Решать, отправлять ли такую, — не дело этого класса.
    func ensureAccess(completion: @escaping (Result<Bool, Error>) -> Void) {
        guard access == nil else { return }

        access = completion

        switch manager.authorizationStatus {
        case .notDetermined:
            //MARK: Ответ придёт в делегат, там и продолжим — синхронного ответа у
            // системного окна нет.
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            requestPrecise()
        default:
            finishAccess(.failure(LocationError.denied))
        }
    }

    private func requestPrecise() {
        guard manager.accuracyAuthorization == .reducedAccuracy else {
            finishAccess(.success(true))
            return
        }

        manager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: LocationProvider.purposeKey) { [weak self] _ in
            guard let self else { return }

            //MARK: Ошибку не разбираем: и отказ, и сбой запроса ведут в одно и то же —
            // точность осталась приблизительной. Важен итог, а не как к нему пришли.
            self.finishAccess(.success(self.manager.accuracyAuthorization == .fullAccuracy))
        }
    }

    private func finishAccess(_ result: Result<Bool, Error>) {
        let completion = access
        access = nil

        completion?(result)
    }

    // MARK: - Шаг второй: координаты

    func locate(completion: @escaping (Result<CLLocation, Error>) -> Void) {
        //MARK: Второй запрос поверх незавершённого игнорируем: `requestLocation()`
        // отвечает один раз, и перезаписанный колбэк остался бы висеть навсегда.
        guard located == nil else { return }

        located = completion
        attemptsLeft = LocationProvider.attempts

        attempt()
    }

    private func attempt() {
        attemptsLeft -= 1

        manager.requestLocation()
    }

    private func finishLocate(_ result: Result<CLLocation, Error>) {
        let completion = located
        located = nil

        completion?(result)
    }
}

extension LocationProvider: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        //MARK: Метод зовётся и при старте, когда никто ничего не просил, — отсюда
        // проверка на висящий запрос.
        guard access != nil else { return }

        switch manager.authorizationStatus {
        case .notDetermined:
            break
        case .authorizedWhenInUse, .authorizedAlways:
            requestPrecise()
        default:
            finishAccess(.failure(LocationError.denied))
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            finishLocate(.failure(LocationError.failed))
            return
        }

        finishLocate(.success(location))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        //MARK: `locationUnknown` означает «пока не поймал», а не «не поймаю»: система сама
        // продолжает попытки, а нам отвечает, что за отведённое время не вышло. Такую
        // ошибку переспрашиваем; остальные — настоящие, их передаём как есть.
        guard (error as? CLError)?.code == .locationUnknown, attemptsLeft > 0 else {
            finishLocate(.failure(error))
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + LocationProvider.pause) { [weak self] in
            guard let self, self.located != nil else { return }

            self.attempt()
        }
    }
}
