// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

#if os(macOS)
    import AppKit
#elseif os(iOS)
    import UIKit
#elseif os(tvOS) || os(watchOS)
    import UIKit
#endif
#if canImport(SwiftUI)
    import SwiftUI
#endif

// Deprecated typealiases
@available(*, deprecated, renamed: "ImageAsset.Image", message: "This typealias will be removed in SwiftGen 7.0")
public typealias AssetImageTypeAlias = ImageAsset.Image

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Asset Catalogs

// swiftlint:disable identifier_name line_length nesting type_body_length type_name
public enum RuuviAsset {
    public enum Resources {
      public static let gateway = ImageAsset(name: "gateway")
      public static let onboardingAlerts = ImageAsset(name: "onboarding_alerts")
      public static let onboardingBeaverSignIn = ImageAsset(name: "onboarding_beaver_sign_in")
      public static let onboardingBeaverStart = ImageAsset(name: "onboarding_beaver_start")
      public static let onboardingBgLayer = ImageAsset(name: "onboarding_bg_layer")
      public static let onboardingDashboard = ImageAsset(name: "onboarding_dashboard")
      public static let onboardingHistory = ImageAsset(name: "onboarding_history")
      public static let onboardingSensors = ImageAsset(name: "onboarding_sensors")
      public static let onboardingShare = ImageAsset(name: "onboarding_share")
      public static let onboardingWeb = ImageAsset(name: "onboarding_web")
      public static let onboardingWidgets = ImageAsset(name: "onboarding_widgets")
    }
    public static let accessData = ImageAsset(name: "access_data")
    public static let arrowDropDown = ImageAsset(name: "arrow_drop_down")
    public static let background = ImageAsset(name: "background")
    public static let baselineKeyboardBackspaceWhite48pt = ImageAsset(name: "baseline_keyboard_backspace_white_48pt")
    public static let baselineMenuWhite48pt = ImageAsset(name: "baseline_menu_white_48pt")
    public static let baselineSettingsWhite48pt = ImageAsset(name: "baseline_settings_white_48pt")
    public static let beaverMail = ImageAsset(name: "beaver-mail")
    public static let bluetoothConnected = ImageAsset(name: "bluetooth-connected")
    public static let bluetoothDisabledIcon = ImageAsset(name: "bluetooth_disabled_icon")
    public static let bluetoothIcon = ImageAsset(name: "bluetooth_icon")
    public static let checkmarkIcon = ImageAsset(name: "checkmark_icon")
    public static let chevronDown = ImageAsset(name: "chevron.down")
    public static let chevronUp = ImageAsset(name: "chevron.up")
    public static let chevronBack = ImageAsset(name: "chevron_back")
    public static let dismissModalIcon = ImageAsset(name: "dismiss-modal-icon")
    public static let editPen = ImageAsset(name: "edit_pen")
    public static let eyeCircle = ImageAsset(name: "eye_circle")
    public static let gestureAssistantHand = ImageAsset(name: "gesture-assistant-hand")
    public static let getStarted = ImageAsset(name: "get_started")
    public static let gradientLayer = ImageAsset(name: "gradient_layer")
    public static let icRefresh = ImageAsset(name: "ic_refresh")
    public static let iconAlertActive = ImageAsset(name: "icon-alert-active")
    public static let iconAlertOff = ImageAsset(name: "icon-alert-off")
    public static let iconAlertOn = ImageAsset(name: "icon-alert-on")
    public static let iconBgCamera = ImageAsset(name: "icon-bg-camera")
    public static let iconBluetoothConnected = ImageAsset(name: "icon-bluetooth-connected")
    public static let iconBluetooth = ImageAsset(name: "icon-bluetooth")
    public static let iconCardsButton = ImageAsset(name: "icon-cards-button")
    public static let iconChartsButton = ImageAsset(name: "icon-charts-button")
    public static let iconConnectable = ImageAsset(name: "icon-connectable")
    public static let iconConnection1 = ImageAsset(name: "icon-connection-1")
    public static let iconConnection2 = ImageAsset(name: "icon-connection-2")
    public static let iconConnection3 = ImageAsset(name: "icon-connection-3")
    public static let iconDeleteForever = ImageAsset(name: "icon-delete-forever")
    public static let iconDownload = ImageAsset(name: "icon-download")
    public static let iconGateway = ImageAsset(name: "icon-gateway")
    public static let iconMeasureHumidity = ImageAsset(name: "icon-measure-humidity")
    public static let iconMeasureLocation = ImageAsset(name: "icon-measure-location")
    public static let iconMeasureMovement = ImageAsset(name: "icon-measure-movement")
    public static let iconMeasurePressure = ImageAsset(name: "icon-measure-pressure")
    public static let iconMeasureSignal = ImageAsset(name: "icon-measure-signal")
    public static let iconRefresh = ImageAsset(name: "icon-refresh")
    public static let iconWarning = ImageAsset(name: "icon-warning")
    public static let iconBackArrow = ImageAsset(name: "icon_back_arrow")
    public static let iconSyncBt = ImageAsset(name: "icon_sync_bt")
    public static let iphoneIcon = ImageAsset(name: "iphone_icon")
    public static let locationPickerPinIcon = ImageAsset(name: "location-picker-pin-icon")
    public static let measureData = ImageAsset(name: "measure_data")
    public static let more3dot = ImageAsset(name: "more_3dot")
    public static let noImage = ImageAsset(name: "no-image")
    public static let overlay = ImageAsset(name: "overlay")
    public static let plusIcon = ImageAsset(name: "plus_icon")
    public static let ruuviCloud = ImageAsset(name: "ruuvi-cloud")
    public static let ruuviActivityPresenterLogo = ImageAsset(name: "ruuvi_activity_presenter_logo")
    public static let ruuviLogo = ImageAsset(name: "ruuvi_logo")
    public static let ruuviStation = ImageAsset(name: "ruuvi_station")
    public static let ruuvitagB8AndOlderButtonLocation = ImageAsset(name: "ruuvitag-b8-and-older-button-location")
    public static let setAlerts = ImageAsset(name: "set_alerts")
    public static let signInBgLayer = ImageAsset(name: "sign_in_bg_layer")
    public static let smallCrossClearIcon = ImageAsset(name: "small-cross-clear-icon")
    public static let tagSettingsInfoIcon = ImageAsset(name: "tag-settings-info-icon")
    public static let tagBgLayer = ImageAsset(name: "tag_bg_layer")
    public static let welcomeFriend1 = ImageAsset(name: "welcome_friend 1")
    public static let welcomeFriend = ImageAsset(name: "welcome_friend")
}
// swiftlint:enable identifier_name line_length nesting type_body_length type_name

// MARK: - Implementation Details

public struct ImageAsset {
    public fileprivate(set) var name: String

    #if os(macOS)
    public typealias Image = NSImage
    #elseif os(iOS) || os(tvOS) || os(watchOS)
    public typealias Image = UIImage
    #endif

    @available(iOS 8.0, tvOS 9.0, watchOS 2.0, macOS 10.7, *)
    public var image: Image {
        let bundle = BundleToken.bundle
        #if os(iOS) || os(tvOS)
        let image = Image(named: name, in: bundle, compatibleWith: nil)
        #elseif os(macOS)
        let name = NSImage.Name(self.name)
        let image = (bundle == .main) ? NSImage(named: name) : bundle.image(forResource: name)
        #elseif os(watchOS)
        let image = Image(named: name)
        #endif
        guard let result = image else {
            fatalError("Unable to load image asset named \(name).")
        }
        return result
    }

    #if os(iOS) || os(tvOS)
    @available(iOS 8.0, tvOS 9.0, *)
    public func image(compatibleWith traitCollection: UITraitCollection) -> Image {
        let bundle = BundleToken.bundle
        guard let result = Image(named: name, in: bundle, compatibleWith: traitCollection) else {
            fatalError("Unable to load image asset named \(name).")
        }
        return result
    }
    #endif

    #if canImport(SwiftUI)
    @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
    public var swiftUIImage: SwiftUI.Image {
        SwiftUI.Image(asset: self)
    }
    #endif
}

public extension ImageAsset.Image {
    @available(iOS 8.0, tvOS 9.0, watchOS 2.0, *)
    @available(macOS, deprecated,
        message: "This initializer is unsafe on macOS, please use the ImageAsset.image property")
    convenience init?(asset: ImageAsset) {
        #if os(iOS) || os(tvOS)
        let bundle = BundleToken.bundle
        self.init(named: asset.name, in: bundle, compatibleWith: nil)
        #elseif os(macOS)
        self.init(named: NSImage.Name(asset.name))
        #elseif os(watchOS)
        self.init(named: asset.name)
        #endif
    }
}

#if canImport(SwiftUI)
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
public extension SwiftUI.Image {
    init(asset: ImageAsset) {
        let bundle = BundleToken.bundle
        self.init(asset.name, bundle: bundle)
    }

    init(asset: ImageAsset, label: Text) {
        let bundle = BundleToken.bundle
        self.init(asset.name, bundle: bundle, label: label)
    }

    init(decorative asset: ImageAsset) {
        let bundle = BundleToken.bundle
        self.init(decorative: asset.name, bundle: bundle)
    }
}
#endif

// swiftlint:disable convenience_type
private final class BundleToken {
    static let bundle: Bundle = {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle(for: BundleToken.self)
        #endif
    }()
}
// swiftlint:enable convenience_type
// swiftlint:enable all