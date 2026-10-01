import SwiftUI
import UIKit

// Present errors on the visible controller, including forms inside sheets.
struct AppErrorPresenter: UIViewControllerRepresentable {
    let message: String?
    let title: String
    let onDismiss: () -> Void
    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }
    func updateUIViewController(_ controller: UIViewController, context: Context) {
        guard let message else { return }
        DispatchQueue.main.async {
            guard let root = controller.view.window?.rootViewController else { return }
            var visible = root
            while let presented = visible.presentedViewController { visible = presented }
            guard !(visible is UIAlertController) else { return }
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in onDismiss() })
            visible.present(alert, animated: true)
        }
    }
}
