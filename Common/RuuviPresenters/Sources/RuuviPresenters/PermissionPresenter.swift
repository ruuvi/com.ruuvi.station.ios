import UIKit

public protocol PermissionPresenter {
    func presentNoPhotoLibraryPermission()
    func presentNoCameraPermission()
    func presentNoLocationPermission()
    func presentNoPushNotificationsPermission()
}
