//
//  AvatarStore.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 12.08.2026.
//

import UIKit
import FirebaseFirestore

//MARK: Аватары — единственное в этом приложении, что лежит в базе **открытым**, и это
// не недосмотр, а следствие требования. Зашифровать их нечем: общего ключа «со всеми»
// не существует, а список контактов показывает всех зарегистрированных, не спрашивая
// ни у кого разрешения. Аватар встаёт в один ряд с логином, именем и заметкой — они
// видны любому вошедшему с самого появления правил.
//
// Байты живут в отдельной коллекции, а не в `users/{uid}`, и вот почему: «Контакты»
// держат слушатель на **всю** коллекцию профилей и перечитывают её при любом изменении
// любого профиля. Аватар внутри профиля означал бы десятки картинок на каждое чужое
// переименование. В профиле остаётся `avatarVersion` — число, по которому видно, что
// картинка сменилась, и по которому её же можно кэшировать.
//
// ```
// avatars/{uid}   data: bytes (JPEG), version: Int
// users/{uid}     avatarVersion: Int   — 0 или нет поля: аватара нет
// ```
final class AvatarStore {

    static let shared = AvatarStore()

    private let ref = Firestore.firestore()

    //MARK: Только в памяти. На диск класть было бы можно — аватар публичен, в отличие
    // от расшифрованных фото из переписки, — но незачем: картинки маленькие, а лишнее
    // хранилище надо чистить при смене аватара и при выходе из аккаунта.
    private let cache = NSCache<NSString, UIImage>()

    //MARK: Уже идущие загрузки. Без них список контактов, перерисованный трижды подряд
    // (а он перерисовывается на любое изменение любого профиля), заказал бы три
    // одинаковых скачивания на каждого человека.
    private var pending: [String: [(UIImage?) -> Void]] = [:]

    private init() {
        cache.countLimit = 100
    }

    private func key(uid: String, version: Int) -> String {
        "\(uid)_\(version)"
    }

    //MARK: Синхронная проверка кэша — для ячеек таблицы: у большинства из них картинка
    // уже есть, и заказывать ради неё асинхронную загрузку значило бы моргать
    // заглушкой на каждой прокрутке.
    func cached(uid: String, version: Int) -> UIImage? {
        guard version > 0 else { return nil }

        return cache.object(forKey: key(uid: uid, version: version) as NSString)
    }

    //MARK: `version == 0` — аватара нет, и в базу за ним никто не ходит. Ради этого
    // маркер и заведён: без него каждый человек без аватара стоил бы промаха в
    // Firestore при каждом показе списка.
    func load(uid: String, version: Int, completion: @escaping (UIImage?) -> Void) {
        guard version > 0 else {
            completion(nil)
            return
        }

        let key = key(uid: uid, version: version)

        if let image = cache.object(forKey: key as NSString) {
            completion(image)
            return
        }

        if pending[key] != nil {
            pending[key]?.append(completion)
            return
        }

        pending[key] = [completion]

        ref.collection(.avatars).document(uid).getDocument { [weak self] snap, err in
            guard let self else { return }

            if let err {
                print("Аватар не загрузился: \(err.localizedDescription)")
            }

            let image = (snap?.data()?["data"] as? Data).flatMap(UIImage.init(data:))

            if let image {
                self.cache.setObject(image, forKey: key as NSString)
            }

            //MARK: Firestore отвечает на главной очереди, поэтому и словарь ожидающих
            // трогается только с неё — блокировка не нужна.
            let waiting = self.pending.removeValue(forKey: key) ?? []
            waiting.forEach { $0(image) }
        }
    }

    //MARK: Версии аватаров участников переписки. Собеседников в чате единицы, а
    // профили их всё равно нигде не читаются — подписи берутся из шапки диалога.
    //
    // Читается это один раз при открытии чата: аватар, сменённый собеседником во время
    // разговора, догонит при следующем открытии. Держать ради него слушатель на чужие
    // профили — цена, которой картинка в кружке не стоит.
    func versions(for uids: [String], completion: @escaping ([String: Int]) -> Void) {
        guard !uids.isEmpty else {
            completion([:])
            return
        }

        let group = DispatchGroup()
        let lock = NSLock()
        var versions: [String: Int] = [:]

        uids.forEach { uid in
            group.enter()

            ref.collection(.users).document(uid).getDocument { snap, _ in
                defer { group.leave() }

                guard let version = snap?.data()?["avatarVersion"] as? Int, version > 0 else { return }

                lock.lock()
                versions[uid] = version
                lock.unlock()
            }
        }

        group.notify(queue: .main) { completion(versions) }
    }

    //MARK: Пишется сначала картинка, потом маркер в профиле — и порядок тот же, что у
    // голосовых: сперва то, за чем пойдут, потом объявление, что оно есть. Маркер
    // проставляет `EditProfileManager`: все записи в `users/{uid}` собраны там.
    //
    // Сжатие уводим с главного потока: снимок с камеры — это мегабайты, и перерисовка
    // с перекодированием заметно подвешивает интерфейс.
    func save(_ image: UIImage, uid: String, version: Int, completion: @escaping (Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            guard let data = AvatarEncoder.encode(image) else {
                DispatchQueue.main.async { completion(AvatarError.tooLarge) }
                return
            }

            DispatchQueue.main.async {
                self.ref.collection(.avatars).document(uid).setData([
                    "data": data,
                    "version": version
                ]) { err in
                    //MARK: Своё же фото кладём в кэш сразу: показывать надо ровно то,
                    // что увидят остальные, — то есть сжатую версию, а не оригинал.
                    if err == nil, let stored = UIImage(data: data) {
                        self.cache.setObject(stored, forKey: self.key(uid: uid, version: version) as NSString)
                    }

                    completion(err)
                }
            }
        }
    }

    func remove(uid: String, completion: @escaping (Error?) -> Void) {
        ref.collection(.avatars).document(uid).delete { err in
            completion(err)
        }
    }
}

enum AvatarError: LocalizedError {
    case tooLarge

    var errorDescription: String? {
        switch self {
        case .tooLarge:
            return "Это изображение не удалось уместить в размер аватара"
        }
    }
}
