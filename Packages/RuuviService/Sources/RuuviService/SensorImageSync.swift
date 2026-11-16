import Foundation
import Future
import RuuviCloud
import RuuviLocal
import RuuviOntology
import UIKit

/// Image reconciliation is independent of sensor metadata reconciliation.
final class SensorImageSync {
    enum Action {
        case upload, download, preserve, none
    }

    enum RetryAction {
        case upload, discard, preserve
    }

    private let images: RuuviLocalImages
    private let cloud: RuuviCloud
    private let loadImage: (URL) -> Future<UIImage, RuuviServiceError>

    init(
        images: RuuviLocalImages,
        cloud: RuuviCloud,
        loadImage: @escaping (URL) -> Future<UIImage, RuuviServiceError> = SensorImageSync.loadImage
    ) {
        self.images = images
        self.cloud = cloud
        self.loadImage = loadImage
    }

    func identifiers(local: RuuviTagSensor, remote: CloudSensor) -> [Identifier] {
        var result: [Identifier] = [remote.id.mac]
        for identifier in [local.macId as Identifier?, local.luid as Identifier?].compactMap({ $0 })
        where !result.contains(where: { $0.value == identifier.value }) {
            result.append(identifier)
        }
        return result
    }

    func selection(local: RuuviTagSensor, remote: CloudSensor) -> (identifier: Identifier, date: Date)? {
        identifiers(local: local, remote: remote)
            .filter { images.hasCustomBackground(for: $0) }
            .compactMap { identifier in
                images.customBackgroundLastUpdated(for: identifier).map { (identifier, $0) }
            }.max { $0.1 < $1.1 }
    }

    func action(local: RuuviTagSensor, remote: CloudSensor) -> Action {
        let identifiers = identifiers(local: local, remote: remote)
        if identifiers.contains(where: { images.isBackgroundWritePending(for: $0) }) { return .preserve }
        if let selected = selection(local: local, remote: remote) {
            if images.isBackgroundUploadForced(for: selected.identifier)
                || remote.picture == nil
                || images.matchesCachedPicture(remote.picture, for: selected.identifier)
                || SyncCollisionResolver.shouldUploadImage(
                    localTimestamp: selected.date, cloudTimestamp: remote.lastUpdated
                ) {
                return .upload
            }
            // lastUpdated includes renames and calibration. It cannot prove a remote image is newer.
            return .preserve
        }
        if let displayed = images.customBackgroundIdentifier(for: local),
           images.cachedPictureURL(for: displayed) == nil {
            // Only the displayed legacy photo needs protection; hidden leftovers are not selections.
            return .preserve
        }
        guard remote.picture != nil else { return .none }
        let cached = images.customBackgroundIdentifier(for: local).map {
            images.matchesCachedPicture(remote.picture, for: $0)
        } ?? false
        return cached ? .none : .download
    }

    func retryAction(
        selectedAt: Date?, local: RuuviTagSensor, remote: CloudSensor
    ) -> RetryAction {
        if let selectedAt, identifiers(local: local, remote: remote).contains(where: {
            (images.backgroundUploadRetiredThrough(for: $0) ?? .distantPast)
                .timeIntervalSince(selectedAt) >= -0.001
        }) { return .discard }
        guard let selectedAt, let current = selection(local: local, remote: remote) else { return .preserve }
        // A newer local selection supersedes this payload. Missing legacy dates are not evidence of staleness.
        if current.date.timeIntervalSince(selectedAt) >= 0.001 { return .discard }
        guard abs(current.date.timeIntervalSince(selectedAt)) < 0.001 else { return .preserve }
        return action(local: local, remote: remote) == .upload ? .upload : .preserve
    }

    func sync(local: RuuviTagSensor, remote: CloudSensor) -> Future<Bool, RuuviServiceError> {
        guard Thread.isMainThread else {
            let result = Promise<Bool, RuuviServiceError>()
            DispatchQueue.main.async {
                self.sync(local: local, remote: remote)
                    .on(success: { result.succeed(value: $0) }, failure: { result.fail(error: $0) })
            }
            return result.future
        }
        switch action(local: local, remote: remote) {
        case .upload:
            guard let selected = selection(local: local, remote: remote) else { return Future(value: false) }
            return upload(
                selectedAt: selected.date, identifier: selected.identifier,
                macId: remote.id.mac, aliases: identifiers(local: local, remote: remote)
            ).map { _ in true }
        case .download:
            return download(local: local, remote: remote).map { _ in true }
        case .preserve:
            return Future(value: false)
        case .none:
            if remote.picture == nil {
                // Only remove a known cloud cache. Local defaults and undated photos are not cloud caches.
                for identifier in identifiers(local: local, remote: remote)
                where images.cachedPictureURL(for: identifier) != nil {
                    images.deleteCustomBackground(for: identifier)
                }
            }
            return completed()
        }
    }

    func claim(local: RuuviTagSensor) -> Future<Bool, RuuviServiceError> {
        guard let macId = local.macId, let identifier = images.customBackgroundIdentifier(for: local) else {
            return completed()
        }
        let selectedAt = Date()
        images.setCustomBackgroundLastUpdated(selectedAt, for: identifier)
        images.setBackgroundUploadForced(true, for: identifier)
        let aliases: [Identifier] = [local.macId as Identifier?, local.luid as Identifier?].compactMap { $0 }
        return upload(
            selectedAt: selectedAt, identifier: identifier,
            macId: macId, aliases: aliases
        ).map { _ in true }
    }

    private func upload(
        selectedAt: Date, identifier: Identifier, macId: MACIdentifier, aliases: [Identifier]
    ) -> Future<URL, RuuviServiceError> {
        // Persisted JPEG bytes are read on a utility queue; sync never decodes/re-encodes images on main.
        images.backgroundUploadData(for: identifier)
            .mapError { RuuviServiceError.ruuviLocal($0) }
            .flatMap { data in
                self.cloud.upload(
                    imageData: data, mimeType: .jpg, lastUpdated: selectedAt, progress: nil,
                    isCurrentSelection: {
                        self.images.customBackgroundLastUpdated(for: identifier) == selectedAt
                    },
                    for: macId
                ).mapError { RuuviServiceError.ruuviCloud($0) }
            }
            .map { url in
                if self.images.customBackgroundLastUpdated(for: identifier) == selectedAt {
                    // An older MAC cache must not hide the winning Bluetooth photo in the UI.
                    for alias in aliases where alias.value != identifier.value
                        && (self.images.customBackgroundLastUpdated(for: alias) ?? .distantPast) <= selectedAt {
                        self.images.deleteCustomBackground(for: alias)
                    }
                }
                self.images.acknowledgeBackgroundUpload(url, selectedAt: selectedAt, for: identifier)
                return url
            }
    }

    func download(local: RuuviTagSensor, remote: CloudSensor) -> Future<URL, RuuviServiceError> {
        let result = Promise<URL, RuuviServiceError>()
        guard let url = remote.picture else {
            result.fail(error: .pictureUrlIsNil)
            return result.future
        }
        guard action(local: local, remote: remote) == .download else {
            result.fail(error: .ruuviCloud(.api(.api(.erConflict))))
            return result.future
        }
        loadImage(url).observe(on: .main).on(success: { image in
            // A photo may have been selected while the network request was running.
            guard self.action(local: local, remote: remote) == .download else {
                result.fail(error: .ruuviCloud(.api(.api(.erConflict))))
                return
            }
            // A missing file with no active write is not a pending local photo.
            for identifier in self.identifiers(local: local, remote: remote)
            where !self.images.hasCustomBackground(for: identifier) {
                self.images.setCustomBackgroundLastUpdated(nil, for: identifier)
                self.images.setBackgroundUploadForced(false, for: identifier)
            }
            let identifier: Identifier = local.macId ?? local.luid ?? remote.id.mac
            self.images.setCustomBackground(image: image, compressionQuality: 1, for: identifier)
                .observe(on: .main)
                .on(success: { fileURL in
                    if self.selection(local: local, remote: remote) == nil {
                        self.images.setCachedPictureURL(url, for: identifier)
                    }
                    result.succeed(value: fileURL)
                }, failure: { result.fail(error: .ruuviLocal($0)) })
        }, failure: { result.fail(error: $0) })
        return result.future
    }

    private func completed() -> Future<Bool, RuuviServiceError> {
        let result = Promise<Bool, RuuviServiceError>()
        result.succeed(value: true)
        return result.future
    }

    private static func loadImage(_ url: URL) -> Future<UIImage, RuuviServiceError> {
        let result = Promise<UIImage, RuuviServiceError>()
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error {
                result.fail(error: .networking(error))
            } else if let data, let image = UIImage(data: data) {
                result.succeed(value: image)
            } else {
                result.fail(error: .failedToParseNetworkResponse)
            }
        }.resume()
        return result.future
    }
}
