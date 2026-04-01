import Foundation

/// The top-level tabs in the app. Used as the `TabView` selection value so
/// any view can programmatically switch tabs by setting `router.selectedTab`.
enum AppTab: Hashable {
    case dashboard
    case search
    case progress
    case settings
}

/// Drives programmatic tab navigation across the app.
///
/// Injected from `AkFitApp` into the environment so child views can change
/// the active tab without prop-drilling or shared mutable globals.
///
/// Usage — jump to Search from any view:
/// ```swift
/// @Environment(AppRouter.self) private var router
/// router.selectedTab = .search
/// ```
@Observable
final class AppRouter {
    var selectedTab: AppTab = .dashboard
    /// Set when a barcode scan from the center nav action resolves to a food item.
    /// `SearchView` watches this and promotes it to a local `scannedFood` navigation
    /// destination once the tab switch animation completes.
    var pendingScannedItem: FoodItem? = nil
}
