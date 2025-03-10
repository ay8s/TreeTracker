import UIKit
import PhotosUI
import BSImagePicker

final class UploadListFlowViewController: NavigationViewController, UploadNavigating, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let assetManager = PHAssetManager()
    private var saveTreesCompletion: ((Bool) -> Void)?

    override init() {
        super.init()

        let rootViewController = CollectionViewController(viewModel: UploadViewModel(navigation: self))
        navigationBar.prefersLargeTitles = true
        navigationBar.tintColor = .white
        viewControllers = [rootViewController]
    }

    func triggerAddTreesFlow(completion: @escaping (Bool) -> Void) {
        saveTreesCompletion = completion
        askForPermissionsAndPresentPickerIfPossible()
    }

    func triggerFillDetailsFlow(phImageIds: [String], completion: @escaping (Bool) -> Void) {
        saveTreesCompletion = completion
        let assets = assetManager.findAssets(for: phImageIds)
        askForDetailsAndStore(assets: assets)
    }

    func triggerEditDetailsFlow(tree: LocalTree, completion: @escaping (Bool) -> Void) {
        saveTreesCompletion = completion
        presentEdit(tree: tree)
    }

    private func askForDetailsAndStore(assets: [PHAsset]) {
        viewControllers.last?.present(TreeDetailsFlowViewController(assets: assets, site: nil, supervisor: nil, completion: saveTreesCompletion), animated: true, completion: nil)
    }

    private func askForPermissionsAndPresentPickerIfPossible() {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized, .limited:
            presentPhotoPicker()
        default:
            PHPhotoLibrary.requestAuthorization { [weak self] status in
                switch status {
                case .authorized, .limited:
                    self?.presentPhotoPicker()
                default:
                    let errorAlert = UIAlertController.error("Tree Tracker doesn't have access to photo library, please update that in Settings in order to use the app to its full potential.")
                    self?.present(errorAlert, animated: true, completion: nil)
                }
            }
        }
    }

    private func presentPhotoPicker() {
        DispatchQueue.main.async {
            if #available(iOS 14, *) {
                self.presentNewPhotoPicker()
            } else {
                self.presentExternalPhotoPicker()
            }
        }
    }

    private func presentLegacyPhotoPicker() {
        let picker = UIImagePickerController()
        picker.mediaTypes = ["public.image"]
        picker.sourceType = .savedPhotosAlbum
        picker.delegate = self

        present(picker, animated: true, completion: nil)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true) {
            guard let asset = info[.phAsset] as? PHAsset else { return }

            self.askForDetailsAndStore(assets: [asset])
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }

    private func presentEdit(tree: LocalTree) {
        viewControllers.last?.present(TreeDetailsFlowViewController(tree: tree, site: nil, supervisor: nil, completion: saveTreesCompletion), animated: true, completion: nil)
    }
}

@available(iOS 14, *)
extension UploadListFlowViewController: PHPickerViewControllerDelegate {
    private func presentNewPhotoPicker() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.selectionLimit = 0
        configuration.filter = .images
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        picker.modalPresentationStyle = .overFullScreen

        present(picker, animated: true, completion: nil)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        let identifiers = results.compactMap { $0.assetIdentifier }
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)

        var assets = [PHAsset]()
        fetchResult.enumerateObjects { asset, index, stop in
            assets.append(asset)
        }

        picker.dismiss(animated: true) {
            if assets.isNotEmpty {
                self.askForDetailsAndStore(assets: assets)
            }
        }
    }
}

extension UploadListFlowViewController {
    private func presentExternalPhotoPicker() {
        let imagePickerController = ImagePickerController()
        imagePickerController.settings.fetch.assets.supportedMediaTypes = [.image]
        presentImagePicker(imagePickerController, select: nil, deselect: nil, cancel: nil) { [weak self] assets in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.askForDetailsAndStore(assets: assets)
            }
        }
    }
}
