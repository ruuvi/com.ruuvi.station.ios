import UIKit
import SwiftUI
import Combine
import RuuviLocalization

protocol TagSettingsImprovedViewInput: ViewInput {
    func render(snapshot: RuuviTagCardSnapshot)
    func updateMaxShareCount(_ count: Int)
    func updateIntent(_ intent: TagSettingsIntent)
}

final class TagSettingsHostingController: UIHostingController<TagSettingsView>, TagSettingsImprovedViewInput {
    private var cancellables = Set<AnyCancellable>()
    private let state: TagSettingsState

    init(
        snapshot: RuuviTagCardSnapshot,
        intent: TagSettingsIntent
    ) {
        let state = TagSettingsState(snapshot: snapshot)
        self.state = state
        super.init(rootView: TagSettingsView(state: state, intent: intent))
        observeSnapshotChanges(snapshot)
    }

    @MainActor
    required dynamic init?(coder aDecoder: NSCoder) {
        let placeholder = RuuviTagCardSnapshot.create(
            id: UUID().uuidString,
            name: RuuviLocalization.na,
            luid: nil,
            mac: nil,
            serviceUUID: nil,
            isCloud: false,
            isOwner: false,
            isConnectable: false,
            version: nil
        )
        let state = TagSettingsState(snapshot: placeholder)
        self.state = state
        super.init(coder: aDecoder, rootView: TagSettingsView(state: state, intent: TagSettingsIntent()))
    }

    func render(snapshot: RuuviTagCardSnapshot) {
        observeSnapshotChanges(snapshot)
        state.snapshot = snapshot
    }

    func updateMaxShareCount(_ count: Int) {
        state.snapshot.ownership.maxShareCount = count
    }

    func updateIntent(_ intent: TagSettingsIntent) {
        rootView = TagSettingsView(state: state, intent: intent)
    }

    private func observeSnapshotChanges(_ snapshot: RuuviTagCardSnapshot) {
        cancellables.removeAll()
        snapshot.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                self.state.snapshot = snapshot
            }
            .store(in: &cancellables)
    }
}
