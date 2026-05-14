import SwiftUI

@Observable
final class AkFitTopBrandLogoState {
    private static let topTolerance: CGFloat = 2

    private var isAtTop = true
    private var isScrollIdle = true
    private var hasUserStartedScrollingAwayFromTop = false

    var isVisible: Bool {
        isAtTop && isScrollIdle && !hasUserStartedScrollingAwayFromTop
    }

    func updateScrollOffset(_ offsetY: CGFloat) {
        isAtTop = offsetY <= Self.topTolerance

        if !isAtTop {
            hasUserStartedScrollingAwayFromTop = true
        } else if isScrollIdle {
            hasUserStartedScrollingAwayFromTop = false
        }
    }

    func updateScrollPhase(_ phase: ScrollPhase) {
        isScrollIdle = phase == .idle

        if phase.isScrolling {
            hasUserStartedScrollingAwayFromTop = true
        } else if isAtTop {
            hasUserStartedScrollingAwayFromTop = false
        }
    }

    func userStartedDragging() {
        hasUserStartedScrollingAwayFromTop = true
    }

    func userEndedDragging() {
        if isAtTop && isScrollIdle {
            hasUserStartedScrollingAwayFromTop = false
        }
    }
}

private struct AkFitTopBrandLogoModifier: ViewModifier {
    let state: AkFitTopBrandLogoState

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                Image("akfit_logo")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(height: 48)
                    .padding(.top, 2)
                    .opacity(state.isVisible ? 1 : 0)
                    .transaction { transaction in
                        transaction.animation = nil
                    }
                    .allowsHitTesting(false)
                    .accessibilityLabel("AkFit")
                    .accessibilityHidden(!state.isVisible)
            }
    }
}

private struct AkFitTopBrandLogoScrollTrackingModifier: ViewModifier {
    let state: AkFitTopBrandLogoState

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                max(0, geometry.contentOffset.y + geometry.contentInsets.top)
            } action: { _, newOffset in
                state.updateScrollOffset(newOffset)
            }
            .onScrollPhaseChange { _, newPhase in
                state.updateScrollPhase(newPhase)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in state.userStartedDragging() }
                    .onEnded { _ in state.userEndedDragging() }
            )
    }
}

extension View {
    /// Adds the fixed AkFit top brand logo overlay.
    func akfitTopBrandLogo(_ state: AkFitTopBrandLogoState) -> some View {
        modifier(AkFitTopBrandLogoModifier(state: state))
    }

    /// Tracks the native scroll container that drives large-title collapse.
    func akfitTracksTopBrandLogoScroll(_ state: AkFitTopBrandLogoState) -> some View {
        modifier(AkFitTopBrandLogoScrollTrackingModifier(state: state))
    }
}
