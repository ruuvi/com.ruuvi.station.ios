import SwiftUI
import UIKit

struct PageViewController<Page: View>: UIViewControllerRepresentable {
    var pages: [Page]
    @Binding var currentPage: Int
    @Binding var scrollProgress: CGFloat
    @Binding var isScrolling: Bool
    var onPageChanged: ((Int) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageViewController = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal)
        pageViewController.dataSource = context.coordinator
        pageViewController.delegate = context.coordinator

        // We must wait until the UIPageViewController has laid out its subviews
        // to find the internal UIScrollView. So we do that on the next main loop:
        DispatchQueue.main.async {
            context.coordinator.configureScrollView(in: pageViewController)
        }

        return pageViewController
    }

    func updateUIViewController(_ pageViewController: UIPageViewController, context: Context) {

        context.coordinator.updatePagesIfNeeded(newPages: pages)

        guard !isScrolling else { return }

        guard !context.coordinator.controllers.isEmpty else { return }

        let oldIndex = context.coordinator.lastPageIndex
        let newIndex = currentPage
        let direction: UIPageViewController.NavigationDirection =
            (newIndex >= oldIndex) ? .forward : .reverse

        pageViewController.setViewControllers(
            [context.coordinator.controllers[newIndex]],
            direction: direction,
            animated: true
        )

        context.coordinator.lastPageIndex = newIndex
    }

    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate, UIScrollViewDelegate {
        var parent: PageViewController
        var controllers = [UIViewController]()
        var lastPageIndex: Int

        // Store the pages from last time, so we can detect changes.
        private var lastPages: [Page] = []

        init(_ pageViewController: PageViewController) {
            parent = pageViewController
            lastPageIndex = parent.currentPage
            super.init()
            controllers = parent.pages.map { UIHostingController(rootView: $0) }
            controllers.forEach({ controller in
                controller.view.backgroundColor = .clear
            })
        }

        func updatePagesIfNeeded(newPages: [Page]) {
            guard newPages.count != lastPages.count
                || !zip(lastPages, newPages).allSatisfy({ $0 as? SensorCardView == $1 as? SensorCardView })
            else {
                return
            }
            lastPages = newPages
            rebuildControllers(newPages)
        }

        private func rebuildControllers(_ pages: [Page]) {
            controllers = pages.map { UIHostingController(rootView: $0) }
            controllers.forEach({ controller in
                controller.view.backgroundColor = .clear
            })
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController) -> UIViewController? {
                guard let index = controllers.firstIndex(of: viewController) else {
                    return nil
                }
                if index == 0 {
                    return nil
                }
                return controllers[index - 1]
            }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController) -> UIViewController? {
                guard let index = controllers.firstIndex(of: viewController) else {
                    return nil
                }
                if index + 1 == controllers.count {
                    return nil
                }
                return controllers[index + 1]
            }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool) {
                if completed,
                   let visibleViewController = pageViewController.viewControllers?.first,
                   let index = controllers.firstIndex(of: visibleViewController) {
                    parent.currentPage = index
                    parent.onPageChanged?(index)

                    guard let scrollView = visibleViewController.view.subviews
                        .compactMap({ $0 as? UIScrollView })
                        .first
                    else {
                        return
                    }
                    scrollViewDidScroll(scrollView)
                }
            }

        // MARK: - UIScrollViewDelegate
        func configureScrollView(in pvc: UIPageViewController) {
            // Find the internal UIScrollView inside the UIPageViewController
            guard let scrollView = pvc.view.subviews
                .compactMap({ $0 as? UIScrollView })
                .first
            else {
                return
            }
            // Set ourselves as the scroll delegate to track partial scrolling
            scrollView.delegate = self
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            parent.isScrolling = true
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            parent.isScrolling = false
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let rawOffset = scrollView.contentOffset.x / scrollView.bounds.width
            let progress = (CGFloat(parent.currentPage) + rawOffset - 1)
            parent.scrollProgress = progress
        }
    }
}
