//
//  PhotoViewerController.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 11.08.2026.
//

import UIKit

//MARK: Снимок во весь экран по нажатию на пузырь. Своего состояния у экрана нет —
// картинка уже расшифрована и лежит в памяти, — поэтому модуля MVP он не заводит:
// презентеру тут нечем управлять, а менеджеру нечего читать.
final class PhotoViewerController: UIViewController {

    private let image: UIImage

    private lazy var scrollView: UIScrollView = {
        $0.delegate = self
        $0.minimumZoomScale = 1
        $0.maximumZoomScale = 4
        $0.showsVerticalScrollIndicator = false
        $0.showsHorizontalScrollIndicator = false
        $0.backgroundColor = .black
        return $0
    }(UIScrollView())

    private lazy var imageView: UIImageView = {
        $0.image = image
        $0.contentMode = .scaleAspectFit
        $0.isUserInteractionEnabled = true
        return $0
    }(UIImageView())

    init(image: UIImage) {
        self.image = image

        super.init(nibName: nil, bundle: nil)

        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        view.addSubview(scrollView)
        scrollView.addSubview(imageView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            imageView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])

        //MARK: Закрытие по тапу, а не кнопкой «Закрыть»: на весь экран открывают, чтобы
        // рассмотреть, и выходят оттуда сразу. Крестик занял бы место поверх снимка.
        // Двойной тап при этом приближает, поэтому одиночный ждёт, пока тот не сорвётся.
        let close = UITapGestureRecognizer(target: self, action: #selector(dismissViewer))
        let zoom = UITapGestureRecognizer(target: self, action: #selector(toggleZoom(_:)))
        zoom.numberOfTapsRequired = 2

        close.require(toFail: zoom)

        view.addGestureRecognizer(close)
        view.addGestureRecognizer(zoom)
    }

    @objc private func dismissViewer() {
        dismiss(animated: true)
    }

    @objc private func toggleZoom(_ gesture: UITapGestureRecognizer) {
        guard scrollView.zoomScale == scrollView.minimumZoomScale else {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            return
        }

        //MARK: Приближаем в точку, по которой нажали, а не в центр экрана: разглядывают
        // обычно край снимка, и прыжок в середину пришлось бы отматывать руками.
        let point = gesture.location(in: imageView)
        let scale = scrollView.maximumZoomScale / 2
        let size = CGSize(width: scrollView.bounds.width / scale,
                          height: scrollView.bounds.height / scale)

        scrollView.zoom(to: CGRect(x: point.x - size.width / 2,
                                   y: point.y - size.height / 2,
                                   width: size.width,
                                   height: size.height),
                        animated: true)
    }
}

extension PhotoViewerController: UIScrollViewDelegate {

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }
}
