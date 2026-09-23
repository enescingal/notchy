enum HUDStep {
    static let normal = 1.0 / 16.0
    static let fine = 1.0 / 64.0

    /// Snaps to the step grid, moves one step, clamps to 0...1 (same behavior as macOS).
    static func next(from value: Double, up: Bool, fine: Bool) -> Double {
        let step = fine ? Self.fine : Self.normal
        let snapped = (value / step).rounded() * step
        let result = up ? snapped + step : snapped - step
        return min(max(result, 0), 1)
    }
}
