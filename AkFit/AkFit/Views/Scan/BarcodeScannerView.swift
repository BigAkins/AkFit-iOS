import SwiftUI
import VisionKit
import AVFoundation

/// Full-screen barcode scanner cover.
///
/// Presented from `SearchView` via the barcode icon in the search toolbar.
///
/// **State machine:**
/// 1. On appear, checks `DataScannerViewController.isSupported` and camera permission.
/// 2. If authorized: shows live camera via `DataScannerViewController` with a
///    corner-bracket viewfinder overlay and an animated scan line.
/// 3. On first barcode detection: plays a medium impact haptic, calls `BarcodeLookupService.lookup`.
/// 4. If found: calls `onFound(_:)` and dismisses — the caller navigates to `FoodDetailView`.
/// 5. If not found: shows a "Product not found" panel; "Try again" resets the scanner,
///    "Search manually" dismisses so the user can type the food name.
/// 6. Unsupported device / denied / restricted: shows clear fallback with action where possible.
///
/// **Swap the lookup layer:** replace `OpenFoodFactsService()` with any
/// `BarcodeLookupService` conformer — the scanner UI is completely decoupled.
struct BarcodeScannerView: View {
    /// Called with the resolved `FoodItem` when a barcode is successfully looked up.
    /// The scanner dismisses itself shortly after calling this.
    let onFound: (FoodItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var scanState: ScanState = .checkingPermission
    /// Incrementing this value forces `DataScannerRepresentable` to be fully
    /// recreated (new VC, new coordinator) so scanning resets after "Try again".
    @State private var scanAttempt: Int = 0
    /// Y-offset of the animated scan line inside the viewfinder brackets.
    @State private var scanLineOffset: CGFloat = -70
    /// Toggled each time a barcode is first detected to trigger the impact haptic.
    @State private var didDetect = false

    private let lookupService: any BarcodeLookupService = OpenFoodFactsService()

    // MARK: - State

    private enum ScanState {
        /// Initial state while permission is being checked.
        case checkingPermission
        /// Camera is live and waiting for a barcode.
        case scanning
        /// A barcode was detected; lookup is in progress.
        case looking
        /// Barcode detected but not found in the lookup database.
        case notFound(String)
        /// `DataScannerViewController.isSupported` returned `false`.
        case unsupported
        /// Camera access was denied by the user.
        case permissionDenied
        /// Camera access is restricted (managed device, parental controls, etc.).
        case permissionRestricted
    }

    /// `true` only during the `.scanning` state. Used to animate hint text in/out
    /// without causing a layout shift.
    private var isActivelyScanning: Bool {
        if case .scanning = scanState { return true }
        return false
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch scanState {
            case .checkingPermission:
                ProgressView()
                    .tint(.white)

            case .scanning, .looking, .notFound:
                cameraLayer
                bracketOverlay
                topBar

                if case .looking = scanState {
                    lookingIndicator
                }
                if case .notFound = scanState {
                    notFoundPanel
                }

            case .permissionDenied:
                permissionBlockView(
                    icon: "camera.slash",
                    title: "Camera access required",
                    message: "AkFit needs camera access to scan barcodes. Open Settings to allow it.",
                    actionLabel: "Open Settings",
                    action: openSettings
                )

            case .permissionRestricted:
                permissionBlockView(
                    icon: "lock.fill",
                    title: "Camera restricted",
                    message: "Camera access is restricted on this device and cannot be enabled.",
                    actionLabel: nil,
                    action: nil
                )

            case .unsupported:
                permissionBlockView(
                    icon: "barcode.viewfinder",
                    title: "Scanner not available",
                    message: "Barcode scanning is not available on this device.",
                    actionLabel: nil,
                    action: nil
                )
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: didDetect)
        .task { await checkPermission() }
    }

    // MARK: - Camera layer

    /// Live camera feed. `.id(scanAttempt)` forces full VC recreation on retry.
    @ViewBuilder
    private var cameraLayer: some View {
        DataScannerRepresentable { barcode in
            // Guard ensures only one lookup runs at a time.
            guard case .scanning = scanState else { return }
            didDetect.toggle()   // triggers the impact haptic
            scanState = .looking
            Task { await lookup(barcode: barcode) }
        }
        .id(scanAttempt)
        .ignoresSafeArea()
    }

    // MARK: - Bracket overlay

    /// Corner-bracket viewfinder with an animated scan line (scanning state only)
    /// and a hint label that fades out via opacity — no layout shift on state change.
    private var bracketOverlay: some View {
        VStack {
            Spacer()

            ZStack {
                ViewfinderBrackets()
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))

                // Animated scan line — only shown while actively scanning.
                if case .scanning = scanState {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.55), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 200, height: 2)
                        .clipShape(RoundedRectangle(cornerRadius: 1))
                        .offset(y: scanLineOffset)
                        .onAppear {
                            scanLineOffset = -70
                            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                                scanLineOffset = 70
                            }
                        }
                        .onDisappear {
                            scanLineOffset = -70
                        }
                }
            }
            .frame(width: 260, height: 170)

            Spacer()

            // Hint text occupies a fixed slot so the brackets never shift.
            Text("Align barcode within the frame")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.70))
                .opacity(isActivelyScanning ? 1 : 0)
                .animation(.easeOut(duration: 0.2), value: isActivelyScanning)
                .padding(.bottom, 90)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        VStack {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            Spacer()
        }
    }

    // MARK: - Looking indicator

    private var lookingIndicator: some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                ProgressView().tint(.white)
                Text("Looking up…")
                    .font(.callout)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .padding(.bottom, 110)
        }
    }

    // MARK: - Not-found panel

    /// Shown when a barcode was detected but returned no match from the lookup service.
    /// Primary action: dismiss so the user can search by name.
    /// Secondary action: try again with the same or a different barcode.
    private var notFoundPanel: some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)

                VStack(spacing: 6) {
                    Text("Product not found")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Try searching by name instead.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 8) {
                    // Primary CTA — most useful action after a miss.
                    Button {
                        dismiss()
                    } label: {
                        Text("Search manually")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.primary)
                            .foregroundStyle(Color(UIColor.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Secondary — if the first scan failed due to angle or lighting.
                    Button("Try again") {
                        scanAttempt += 1
                        scanState = .scanning
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
                }
                .padding(.top, 2)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 32)
            .padding(.bottom, 60)
        }
    }

    // MARK: - Permission block view

    private func permissionBlockView(
        icon: String,
        title: String,
        message: String,
        actionLabel: String?,
        action: (() -> Void)?
    ) -> some View {
        VStack(spacing: 0) {
            topBar
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 52))
                    .foregroundStyle(.white.opacity(0.55))
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                if let actionLabel, let action {
                    Button(actionLabel, action: action)
                        .buttonStyle(.bordered)
                        .tint(.white)
                        .padding(.top, 8)
                }
            }
            Spacer()
        }
    }

    // MARK: - Logic

    private func checkPermission() async {
        guard DataScannerViewController.isSupported else {
            scanState = .unsupported
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            scanState = .scanning
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            scanState = granted ? .scanning : .permissionDenied
        case .denied:
            scanState = .permissionDenied
        case .restricted:
            scanState = .permissionRestricted
        @unknown default:
            scanState = .permissionDenied
        }
    }

    private func lookup(barcode: String) async {
        let result = await lookupService.lookup(barcode: barcode)
        switch result {
        case .found(let food):
            onFound(food)
            // Brief pause so the impact haptic completes before the cover dismisses.
            try? await Task.sleep(for: .milliseconds(200))
            dismiss()
        case .notFound:
            scanState = .notFound(barcode)
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Corner bracket shape

/// Four L-shaped corner brackets drawn as a single SwiftUI `Shape`.
/// Apply `.stroke(...)` to control color and line weight.
private struct ViewfinderBrackets: Shape {
    var cornerLength: CGFloat = 30

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = cornerLength

        // Top-left
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + c))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + c, y: rect.minY))

        // Top-right
        p.move(to: CGPoint(x: rect.maxX - c, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + c))

        // Bottom-right
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - c))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - c, y: rect.maxY))

        // Bottom-left
        p.move(to: CGPoint(x: rect.minX + c, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - c))

        return p
    }
}

// MARK: - DataScanner representable

/// Wraps `DataScannerViewController` (VisionKit) in a SwiftUI view.
///
/// Reports the first barcode payload via `onBarcode`. Subsequent detections
/// are suppressed by the `hasReported` flag on the coordinator.
/// To reset scanning, change the `.id(_:)` on this view — SwiftUI will
/// recreate the VC and coordinator from scratch.
private struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onBarcode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: false
        )
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {
        guard !vc.isScanning else { return }
        try? vc.startScanning()
    }

    static func dismantleUIViewController(_ vc: DataScannerViewController, coordinator: Coordinator) {
        vc.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onBarcode: onBarcode)
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onBarcode: (String) -> Void
        /// Prevents calling `onBarcode` more than once per scan attempt.
        private var hasReported = false

        init(onBarcode: @escaping (String) -> Void) {
            self.onBarcode = onBarcode
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !hasReported else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item,
                   let payload = barcode.payloadStringValue {
                    hasReported = true
                    DispatchQueue.main.async { self.onBarcode(payload) }
                    return
                }
            }
        }
    }
}
