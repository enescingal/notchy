import Combine

/// Runtime state the settings UI shows (not persisted).
@MainActor
final class ModuleStatus: ObservableObject {
    @Published var mediaUnavailable = false
    @Published var accessibilityGranted = Accessibility.isTrusted
    @Published var hasNotch = true
}
