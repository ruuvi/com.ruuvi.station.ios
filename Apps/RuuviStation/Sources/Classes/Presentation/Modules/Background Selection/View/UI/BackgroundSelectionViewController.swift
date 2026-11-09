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
    private let sectionTopPadding: CGFloat = 4
    private let sectionBottomPadding: CGFloat = 12
    /// The layout class the grid was last laid out for (see `viewWillLayoutSubviews`).
    private var appliedLayoutClass: RuuviLayoutClass?
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

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        // The grid re-runs its section provider when its size changes. Also re-run it when only the
        // size classes change, so it never keeps the variant of another layout class.
        let layoutClass = view.traitCollection.ruuviLayoutClass
        if let appliedLayoutClass, appliedLayoutClass != layoutClass {
            collectionView.collectionViewLayout.invalidateLayout()
        }
        appliedLayoutClass = layoutClass
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
        if #unavailable(iOS 26) {
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
            environment: NSCollectionLayoutEnvironment
        )
            -> NSCollectionLayoutSection? in
        guard let sSelf = self else { return nil }

        let grid = sSelf.gridMetrics(for: environment)

        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(grid.itemWidthFraction),
            heightDimension: .absolute(grid.itemHeight)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(
            top: 0,
            leading: grid.itemHorizontalSpacing,
            bottom: 0,
            trailing: grid.itemHorizontalSpacing
        )

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(grid.itemHeight)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = grid.itemGroupSpacing
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
}

// MARK: - Grid variants

private extension BackgroundSelectionViewController {
    /// One grid variant: the share of a row one item takes, its height and the spacings.
    struct GridMetrics {
        let itemWidthFraction: CGFloat
        let itemHeight: CGFloat
        let itemHorizontalSpacing: CGFloat
        let itemGroupSpacing: CGFloat
    }

    /// In the `.regular` layout, the widest column that still shows 5 per row. The collection view is
    /// 24 pt narrower than the window: full-screen iPad portrait (720-1008 pt, columns up to 201.6 pt)
    /// keeps 5 per row and landscape (1056-1352 pt, 5 columns would be 211.2 pt or wider) keeps 8, as
    /// before. 206 sits midway; other widths get the count that fits.
    static let regularMaximumColumnWidth: CGFloat = 206

    /// Picks the grid from the collection view's own traits and width, never from the device type
    /// or orientation: iPhone portrait 3 per row, iPhone landscape 5, iPad 5 or 8.
    func gridMetrics(for environment: NSCollectionLayoutEnvironment) -> GridMetrics {
        switch environment.traitCollection.ruuviLayoutClass {
        case .compactWidth:
            return GridMetrics(
                itemWidthFraction: 0.33333333,
                itemHeight: 170,
                itemHorizontalSpacing: 4,
                itemGroupSpacing: 8
            )
        case .compactHeight:
            return GridMetrics(
                itemWidthFraction: 0.20,
                itemHeight: 190,
                itemHorizontalSpacing: 4,
                itemGroupSpacing: 8
            )
        case .regular:
            let columns = RuuviGridFit.columns(
                in: environment.container.effectiveContentSize.width,
                counts: [5, 8],
                maximumColumnWidth: Self.regularMaximumColumnWidth
            )
            return GridMetrics(
                itemWidthFraction: columns == 8 ? 0.125 : 0.20,
                itemHeight: columns == 8 ? 200 : 190,
                itemHorizontalSpacing: 8,
                itemGroupSpacing: 20
            )
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
