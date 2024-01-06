import ComposableArchitecture
import RuuviLocalization
import SwiftUI

struct OnboardView: View {
    let store: StoreOf<OnboardFeature>
    @State private var currentPage = 0
    private let pages = buildOnboardingPages()

    var body: some View {
        NavigationStackStore(self.store.scope(state: \.dashboard, action: \.routeToDashboard)) {
            ZStack {
                RuuviAsset.Onboarding.onboardingBgLayer
                    .swiftUIImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                VStack {
                    PageIndicator(currentPage: $currentPage, pageCount: pages.count)
                    TabView(selection: $currentPage) {
                        ForEach(pages, id: \.pageType.rawValue) { page in
                            OnboardPage(store: store, page: page)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                }
                if currentPage == 0 {
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                currentPage = pages.count - 1
                            } label: {
                                Text(RuuviLocalization.onboardingSkip)
                            }

                        }
                        .padding()
                        Spacer()
                    }
                }
            }
        } destination: { store in
            DashboardView(store: store)
        }.sheet(
            store: self.store.scope(
                state: \.$benefits,
                action: \.routeToBenefits
            )
        ) { benefitsStore in
            NavigationStack {
                BenefitsView(store: benefitsStore)
            }
        }
    }
}

struct OnboardPage: View {
    let store: StoreOf<OnboardFeature>
    var page: OnboardViewModel
    var body: some View {
        VStack {
            Text(page.title)
                .font(.title)
                .padding(4)
            Text(page.subtitle)
                .font(.headline)
                .padding(4)
            if let subSubtitle = page.subSubtitle {
                Text(subSubtitle)
                    .font(.subheadline)
                    .padding(4)
            }
            if page.hasContinue {
                Button {
                    store.send(.onContinue)
                } label: {
                    Text(RuuviLocalization.onboardingContinue)
                }
                .buttonStyle(.borderedProminent)
            }
            page.image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding()
        }
        .padding()
    }
}

struct PageIndicator: View {
    @Binding var currentPage: Int
    let pageCount: Int
    var body: some View {
        HStack {
            ForEach(0..<pageCount, id: \.self) { index in
                Circle()
                    .fill(currentPage == index ? Color.white : Color.gray)
                    .frame(width: 10, height: 10)
            }
        }
        .padding(.top, 20)
    }
}
