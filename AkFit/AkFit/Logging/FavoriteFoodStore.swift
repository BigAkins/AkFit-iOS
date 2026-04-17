import Foundation
import Supabase

/// Owns the in-session favorites state and Supabase read/write operations
/// for the `favorite_foods` table.
///
/// Injected into the SwiftUI environment from `AkFitApp`, alongside `FoodLogStore`.
///
/// ## Matching strategy
/// A favorite is uniquely identified by `(foodName, servingLabel)` — the same
/// pair that is constrained to be unique per user in the DB schema. This pair
/// is stable across all food sources (generic and Open Food Facts), unlike
/// the `FoodItem.id` UUID which is ephemeral for OFF results.
///
/// ## Toggle pattern
/// `toggle(food:for:)` checks in-memory state first, so the star button
/// responds instantly. The Supabase write happens in the background; if it
/// throws, the caller can surface an error (the optimistic update is NOT
/// reverted — next `refresh` call will re-sync).
@Observable
final class FavoriteFoodStore {

    // MARK: - State

    /// All favorited foods for the current user, newest first.
    /// Updated optimistically after each `toggle` call.
    private(set) var favorites: [FavoriteFood] = []

    // MARK: - Dependencies

    private let authManager: AuthManager?

    // MARK: - Init

    /// Production initializer. Pass the shared `AuthManager` from `AkFitApp`
    /// so `toggle` can pre-flight the session via
    /// `AuthManager.requireAuthenticatedUserIDForWrite()` before the write.
    ///
    /// Also used as the preview initializer: omit `authManager` and pass
    /// `previewFavorites` to seed state in `#Preview` blocks without a
    /// network call.
    init(
        authManager:      AuthManager?     = nil,
        previewFavorites: [FavoriteFood]   = []
    ) {
        self.authManager = authManager
        self.favorites   = previewFavorites
    }

    // MARK: - Query

    /// Returns `true` if a food with the same name and serving label is in `favorites`.
    ///
    /// Called from views synchronously — no async work needed.
    func isFavorite(_ food: FoodItem) -> Bool {
        favorites.contains { $0.foodName == food.name && $0.servingLabel == food.servingSize }
    }

    // MARK: - Fetch

    /// Loads all favorites for `userId` from Supabase, ordered newest first.
    /// Replaces `favorites` on success; leaves it unchanged on error (non-fatal).
    ///
    /// Called once on `SearchView` first appear via `.task`, concurrently with
    /// `FoodLogStore.refreshRecents`.
    func refresh(userId: UUID) async {
        do {
            let rows: [FavoriteFood] = try await SupabaseClientProvider.shared
                .from("favorite_foods")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            favorites = rows
        } catch {
            // Non-fatal: favorites stays empty or stale.
        }
    }

    // MARK: - Reset

    func reset() {
        favorites = []
    }

    // MARK: - Toggle

    /// Adds `food` to favorites if it is not already saved; removes it if it is.
    ///
    /// In-memory state is updated optimistically before the network call so
    /// the star button responds instantly. Throws on Supabase errors so
    /// the caller can surface feedback if desired.
    func toggle(food: FoodItem, for userId: UUID) async throws {
        if let existing = favorites.first(where: {
            $0.foodName == food.name && $0.servingLabel == food.servingSize
        }) {
            // Optimistic remove
            favorites.removeAll { $0.id == existing.id }
            do {
                // Validate the session before the delete; RLS scopes it to the owner.
                _ = try await authManager?.requireAuthenticatedUserIDForWrite()
                try await SupabaseClientProvider.shared
                    .from("favorite_foods")
                    .delete()
                    .eq("id", value: existing.id.uuidString)
                    .execute()
            } catch {
                // Revert optimistic remove on failure
                favorites.insert(existing, at: 0)
                throw error
            }
        } else {
            // Optimistic add — create a placeholder so the star fills immediately
            let placeholder = FavoriteFood(
                id:              UUID(),
                userId:          userId,
                foodName:        food.name,
                servingLabel:    food.servingSize,
                servingWeightG:  food.servingWeightG,
                calories:        food.calories,
                proteinG:        food.proteinG,
                carbsG:          food.carbsG,
                fatG:            food.fatG,
                brandOrCategory: food.brandOrCategory,
                createdAt:       Date()
            )
            favorites.insert(placeholder, at: 0)
            do {
                // Validate the session (refreshing once if needed) before the insert.
                let validUserId = (try await authManager?.requireAuthenticatedUserIDForWrite()) ?? userId
                let payload = FavoriteFoodInsert(
                    userId:          validUserId,
                    foodName:        food.name,
                    servingLabel:    food.servingSize,
                    servingWeightG:  food.servingWeightG,
                    calories:        food.calories,
                    proteinG:        food.proteinG,
                    carbsG:          food.carbsG,
                    fatG:            food.fatG,
                    brandOrCategory: food.brandOrCategory
                )
                let saved: FavoriteFood = try await SupabaseClientProvider.shared
                    .from("favorite_foods")
                    .insert(payload)
                    .select()
                    .single()
                    .execute()
                    .value
                // Replace placeholder with the server-confirmed row (gets real id + created_at)
                if let idx = favorites.firstIndex(where: { $0.id == placeholder.id }) {
                    favorites[idx] = saved
                }
            } catch {
                // Revert optimistic add on failure
                favorites.removeAll { $0.id == placeholder.id }
                throw error
            }
        }
    }
}

// MARK: - Insert payload

/// Encodable struct for inserting a new row. Excludes `id` and `created_at`
/// so Postgres uses its own defaults.
private struct FavoriteFoodInsert: Encodable {
    let userId:          UUID
    let foodName:        String
    let servingLabel:    String
    let servingWeightG:  Double
    let calories:        Int
    let proteinG:        Double
    let carbsG:          Double
    let fatG:            Double
    let brandOrCategory: String?

    enum CodingKeys: String, CodingKey {
        case userId          = "user_id"
        case foodName        = "food_name"
        case servingLabel    = "serving_label"
        case servingWeightG  = "serving_weight_g"
        case calories
        case proteinG        = "protein_g"
        case carbsG          = "carbs_g"
        case fatG            = "fat_g"
        case brandOrCategory = "brand_or_category"
    }
}
