import SwiftUI

private enum AkFitTopBrandLogoMetrics {
    static let topTolerance: CGFloat = 2
    static let dragMinimumDistance: CGFloat = 8
}

@Observable
final class AkFitTopBrandLogoState {
    private var isAtTop = true
    private var isRootScreenActive = true
    private var isScrollMovementActive = false
    private var hasUserStartedScrollingAwayFromTop = false

    var isVisible: Bool {
        isRootScreenActive && isAtTop && !isScrollMovementActive && !hasUserStartedScrollingAwayFromTop
    }

    func setRootScreenActive(_ isActive: Bool) {
        isRootScreenActive = isActive
    }

    func updateScrollDistanceFromTop(_ distanceFromTop: CGFloat) {
        isAtTop = distanceFromTop <= AkFitTopBrandLogoMetrics.topTolerance

        if !isAtTop {
            hasUserStartedScrollingAwayFromTop = true
        } else if !isScrollMovementActive {
            hasUserStartedScrollingAwayFromTop = false
        }
    }

    func updateScrollPhase(_ phase: ScrollPhase) {
        let isMoving = phase == .interacting || phase == .decelerating
        isScrollMovementActive = isMoving

        if isMoving {
            hasUserStartedScrollingAwayFromTop = true
        } else if isAtTop {
            hasUserStartedScrollingAwayFromTop = false
        }
    }

    func userStartedDragging() {
        hasUserStartedScrollingAwayFromTop = true
    }

    func userEndedDragging() {
        if isAtTop && !isScrollMovementActive {
            hasUserStartedScrollingAwayFromTop = false
        }
    }
}

private struct AkFitTopBrandLogoScrollPosition: Equatable {
    let rawOffsetY: CGFloat
    let adjustedTopOffsetY: CGFloat
}

private struct AkFitTopBrandLogoModifier: ViewModifier {
    let state: AkFitTopBrandLogoState
    let isSuppressed: Bool

    private var isVisible: Bool {
        state.isVisible && !isSuppressed
    }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                Image("akfit_logo")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(height: 48)
                    .padding(.top, 2)
                    .opacity(isVisible ? 1 : 0)
                    .transaction { transaction in
                        transaction.animation = nil
                    }
                    .allowsHitTesting(false)
                    .accessibilityLabel("AkFit")
                    .accessibilityHidden(!isVisible)
            }
    }
}

private struct AkFitTopBrandLogoScrollTrackingModifier: ViewModifier {
    let state: AkFitTopBrandLogoState
    @State private var topContentOffsetY: CGFloat?

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: AkFitTopBrandLogoScrollPosition.self) { geometry in
                AkFitTopBrandLogoScrollPosition(
                    rawOffsetY: geometry.contentOffset.y,
                    adjustedTopOffsetY: geometry.contentOffset.y + geometry.contentInsets.top
                )
            } action: { _, newOffset in
                if topContentOffsetY == nil {
                    topContentOffsetY = newOffset.rawOffsetY
                }

                if abs(newOffset.adjustedTopOffsetY) <= AkFitTopBrandLogoMetrics.topTolerance {
                    topContentOffsetY = min(topContentOffsetY ?? newOffset.rawOffsetY, newOffset.rawOffsetY)
                }

                let topOffset = topContentOffsetY ?? newOffset.rawOffsetY
                let distanceFromTop = max(0, newOffset.rawOffsetY - topOffset)
                state.updateScrollDistanceFromTop(distanceFromTop)
            }
            .onScrollPhaseChange { _, newPhase in
                state.updateScrollPhase(newPhase)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: AkFitTopBrandLogoMetrics.dragMinimumDistance)
                    .onChanged { _ in state.userStartedDragging() }
                    .onEnded { _ in state.userEndedDragging() }
            )
    }
}

extension View {
    /// Adds the fixed AkFit top brand logo overlay.
    func akfitTopBrandLogo(
        _ state: AkFitTopBrandLogoState,
        isSuppressed: Bool = false
    ) -> some View {
        modifier(AkFitTopBrandLogoModifier(state: state, isSuppressed: isSuppressed))
    }

    /// Tracks the native scroll container that drives large-title collapse.
    func akfitTracksTopBrandLogoScroll(_ state: AkFitTopBrandLogoState) -> some View {
        modifier(AkFitTopBrandLogoScrollTrackingModifier(state: state))
    }
}
