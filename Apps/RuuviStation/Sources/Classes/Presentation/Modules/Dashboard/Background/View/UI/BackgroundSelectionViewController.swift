import RuuviLocalization
import UIKit

class BackgroundSelectionViewController: UIViewController {
    // View configure
    var output: BackgroundSelectionViewOutput!
    var viewModel: BackgroundSelectionViewModel? {
        didSet {
            updateUI()
        }
    }

    // UI Componenets starts
    private lazy var backButton: UIButton = {
        let button = UIButton()
        button.tintColor = .label
        let buttonImage = RuuviAsset.chevronBack.image
        button.setImage(buttonImage, for: .normal)
        button.setImage(buttonImage, for: .highlighted)
        button.imageView?.tintColor = .label
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(backButtonDidTap), for: .touchUpInside)
        return button
    }()

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(
            frame: .zero,
            collectionViewLayout: createLayout()
        )
        cv.backgroundColor = .clear
        cv.showsVerticalScrollIndicator = false
        cv.delegate = self
        return cv
    }()

    private lazy var uploadProgressView = BackgroundSelectionUploadProgressView()
    // UI Componenets ends

    // Private properties
    private let sectionHeaderIdentifier: String = "sectionHeaderIdentifier"
    private let sectionHeaderKind: String = "sectionHeaderKind"
    private let cvCellIdentifier: String = "cvCellIdentifier"
    // Collection view layout properties
    private let itemHorizontalSpacing: CGFloat = GlobalHelpers.isDeviceTablet() ? 8 : 4
    private let itemGroupSpacing: CGFloat = GlobalHelpers.isDeviceTablet() ? 20 : 8
    private let sectionTopPadding: CGFloat = 4
    private let sectionBottomPadding: CGFloat = 12
}

// MARK: - View lifecycle

extension BackgroundSelectionViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        bindViewModel()
        localize()
        output.viewDidLoad()
    }
}

private extension BackgroundSelectionViewController {
    func updateUI() {
        DispatchQueue.main.async { [weak self] in
            self?.collectionView.reloadData()
        }
    }

    @objc func backButtonDidTap() {
        _ = navigationController?.popViewController(animated: true)
    }
}

private extension BackgroundSelectionViewController {
    func setUpUI() {
        setUpBaseView()
        setUpHeaderView()
        setUpContentView()
        setUpUploadProgressView()
    }

    func setUpBaseView() {
        view.backgroundColor = RuuviColor.dashboardBG.color
    }

    func setUpHeaderView() {
        let leftBarButtonView = UIView(color: .clear)

        leftBarButtonView.addSubview(backButton)
        backButton.anchor(
            top: leftBarButtonView.topAnchor,
            leading: leftBarButtonView.leadingAnchor,
            bottom: leftBarButtonView.bottomAnchor,
            trailing: leftBarButtonView.trailingAnchor,
            padding: .init(top: 0, left: -16, bottom: 0, right: 0),
            size: .init(width: 48, height: 48)
        )

        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: leftBarButtonView)
    }

    func setUpContentView() {
        view.addSubview(collectionView)
        collectionView.anchor(
            top: view.safeTopAnchor,
            leading: view.safeLeftAnchor,
            bottom: view.bottomAnchor,
            trailing: view.safeRightAnchor,
            padding: .init(
                top: 0,
                left: 12,
                bottom: 0,
                right: 12
            )
        )

        collectionView.dataSource = self
        collectionView.register(
            BackgroundSelectionViewCell.self,
            forCellWithReuseIdentifier: cvCellIdentifier
        )
        collectionView.register(
            BackgroundSelectionViewHeader.self,
            forSupplementaryViewOfKind: sectionHeaderKind,
            withReuseIdentifier: sectionHeaderIdentifier
        )
    }

    func setUpUploadProgressView() {
        view.addSubview(uploadProgressView)
        uploadProgressView.anchor(
            top: nil,
            leading: nil,
            bottom: view.safeBottomAnchor,
            trailing: nil,
            padding: .init(top: 0, left: 0, bottom: 8, right: 0),
            size: .init(width: 0, height: 44)
        )
        uploadProgressView.centerXInSuperview()
        uploadProgressView.delegate = self
        uploadProgressView.isHidden = true
    }

    // swiftlint:disable:next function_body_length
    func createLayout() -> UICollectionViewLayout {
        let sectionProvider = { [weak self] (
            _: Int,
            _: NSCollectionLayoutEnvironment
        )
            -> NSCollectionLayoutSection? in
        guard let sSelf = self else { return nil }

        let widthMultiplier = sSelf.itemWidthMultiplier()
        let itemEstimatedHeight: CGFloat = sSelf.itemEstimatedHeight()

        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(widthMultiplier),
            heightDimension: .absolute(itemEstimatedHeight)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(
            top: 0,
            leading: sSelf.itemHorizontalSpacing,
            bottom: 0,
            trailing: sSelf.itemHorizontalSpacing
        )

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(itemEstimatedHeight)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = sSelf.itemGroupSpacing
        section.contentInsets = NSDirectionalEdgeInsets(
            top: sSelf.sectionTopPadding,
            leading: 0,
            bottom: sSelf.sectionBottomPadding,
            trailing: 0
        )
        return section
        }

        // Header
        let globalHeaderSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(1)
        )
        let globalHeader = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: globalHeaderSize,
            elementKind: sectionHeaderKind,
            alignment: .top
        )
        globalHeader.pinToVisibleBounds = false

        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.scrollDirection = .vertical
        config.boundarySupplementaryItems = [globalHeader]
        let layout = UICollectionViewCompositionalLayout(
            sectionProvider: sectionProvider,
            configuration: config
        )
        return layout
    }

    func itemWidthMultiplier() -> CGFloat {
        if GlobalHelpers.isDeviceTablet() {
            GlobalHelpers.isDeviceLandscape() ? 0.125 : 0.20
        } else {
            GlobalHelpers.isDeviceLandscape() ? 0.20 : 0.33333333
        }
    }

    func itemEstimatedHeight() -> CGFloat {
        if GlobalHelpers.isDeviceTablet() {
            GlobalHelpers.isDeviceLandscape() ? 200 : 190
        } else {
            GlobalHelpers.isDeviceLandscape() ? 190 : 170
        }
    }
}

extension BackgroundSelectionViewController {
    private func bindViewModel() {
        guard isViewLoaded, let viewModel else { return }

        collectionView.bind(viewModel.defaultImages) { [weak self] _, _ in
            self?.updateUI()
        }

        uploadProgressView.bind(viewModel.isUploadingBackground) { v, isUploading in
            if let isUploading {
                v.isHidden = !isUploading
            } else {
                v.isHidden = true
            }
        }

        uploadProgressView.progressLabel.bind(viewModel.uploadingBackgroundPercentage) { lb, percentage in
            if let percentage {
                lb.text = RuuviLocalization.uploadingProgress(Float(percentage) * 100)
            }
        }
    }
}

extension BackgroundSelectionViewController: BackgroundSelectionViewInput {
    func localize() {
        title = RuuviLocalization.changeBackground
    }

    func viewShouldDismiss() {
        backButtonDidTap()
    }
}

extension BackgroundSelectionViewController: UICollectionViewDataSource {
    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        viewModel?.defaultImages.value?.count ?? 0
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: cvCellIdentifier,
            for: indexPath
        ) as? BackgroundSelectionViewCell
        else {
            fatalError()
        }

        let model = viewModel?.defaultImages.value?[indexPath.item]
        cell.configure(with: model)
        return cell
    }
}

extension BackgroundSelectionViewController: UICollectionViewDelegate {
    func collectionView(
        _: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        if let model = viewModel?.defaultImages.value?[indexPath.item] {
            output.viewDidSelectDefaultPhoto(model: model)
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind _: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        guard let headerView = collectionView
            .dequeueReusableSupplementaryView(
                ofKind: sectionHeaderKind,
                withReuseIdentifier: sectionHeaderIdentifier,
                for: indexPath
            ) as? BackgroundSelectionViewHeader
        else {
            fatalError()
        }
        headerView.delegate = self
        return headerView
    }
}

extension BackgroundSelectionViewController: BackgroundSelectionViewHeaderDelegate {
    func didTapSelectionButton(mode: SelectionMode) {
        switch mode {
        case .camera:
            output.viewDidAskToSelectCamera()
        case .gallery:
            output.viewDidAskToSelectGallery()
        }
    }
}

extension BackgroundSelectionViewController: BackgroundSelectionUploadProgressViewDelegate {
    func didTapCancel() {
        output.viewDidCancelUpload()
    }
}
