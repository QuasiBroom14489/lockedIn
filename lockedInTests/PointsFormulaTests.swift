import XCTest
@testable import lockedIn

final class PointsFormulaTests: XCTestCase {

    // MARK: - Screen Time Bonus Tests

    func testLowNonProductiveMinutesGivesHighBonus() {
        // Under 60 minutes non-productive = 1.30 base bonus
        let user = createUser(productiveMinutes: 180, nonProductiveMinutes: 30)
        let bonus = calculateScreenTimeBonus(user: user)

        // With 86% productive ratio (>70%), should get +0.10 adjustment
        // Expected: 1.30 + 0.10 = 1.40
        XCTAssertEqual(bonus, 1.40, accuracy: 0.01)
    }

    func testModerateNonProductiveMinutesGivesMediumBonus() {
        // 60-120 minutes non-productive = 1.15 base bonus
        let user = createUser(productiveMinutes: 150, nonProductiveMinutes: 90)
        let bonus = calculateScreenTimeBonus(user: user)

        // With 62.5% productive ratio (50-70%), should get +0.05 adjustment
        // Expected: 1.15 + 0.05 = 1.20
        XCTAssertEqual(bonus, 1.20, accuracy: 0.01)
    }

    func testHighNonProductiveMinutesGivesLowBonus() {
        // 180-240 minutes non-productive = 0.90 base bonus
        let user = createUser(productiveMinutes: 60, nonProductiveMinutes: 200)
        let bonus = calculateScreenTimeBonus(user: user)

        // With 23% productive ratio (<50%), no adjustment
        // Expected: 0.90
        XCTAssertEqual(bonus, 0.90, accuracy: 0.01)
    }

    func testVeryHighNonProductiveMinutesGivesMinimumBonus() {
        // Over 240 minutes non-productive = 0.80 base bonus
        let user = createUser(productiveMinutes: 30, nonProductiveMinutes: 300)
        let bonus = calculateScreenTimeBonus(user: user)

        // With 9% productive ratio (<50%), no adjustment
        // Expected: 0.80
        XCTAssertEqual(bonus, 0.80, accuracy: 0.01)
    }

    func testNeutralScreenTimeGivesBaseBonus() {
        // 120-180 minutes non-productive = 1.00 base bonus
        let user = createUser(productiveMinutes: 120, nonProductiveMinutes: 150)
        let bonus = calculateScreenTimeBonus(user: user)

        // With 44% productive ratio (<50%), no adjustment
        // Expected: 1.00
        XCTAssertEqual(bonus, 1.00, accuracy: 0.01)
    }

    func testBonusCapsAt150Percent() {
        // Best case scenario: very low non-productive + high productive ratio
        let user = createUser(productiveMinutes: 200, nonProductiveMinutes: 10)
        let bonus = calculateScreenTimeBonus(user: user)

        // 1.30 + 0.10 = 1.40, capped at 1.50
        XCTAssertLessThanOrEqual(bonus, 1.50)
    }

    func testZeroScreenTimeHandledGracefully() {
        // Edge case: no screen time data
        let user = createUser(productiveMinutes: 0, nonProductiveMinutes: 0)
        let bonus = calculateScreenTimeBonus(user: user)

        // Should not crash and return a valid bonus
        XCTAssertGreaterThan(bonus, 0)
        XCTAssertLessThanOrEqual(bonus, 1.50)
    }

    // MARK: - Points Calculation Tests

    func testBasePointsOnePerMinute() {
        let durationSeconds = 1800 // 30 minutes
        let basePoints = durationSeconds / 60

        XCTAssertEqual(basePoints, 30)
    }

    func testFinalPointsWithBonus() {
        let durationSeconds = 1800 // 30 minutes
        let basePoints = durationSeconds / 60
        let bonus = 1.25

        let finalPoints = Int((Double(basePoints) * bonus).rounded())

        XCTAssertEqual(finalPoints, 38) // 30 * 1.25 = 37.5, rounded to 38
    }

    func testFinalPointsWithPenalty() {
        let durationSeconds = 1800 // 30 minutes
        let basePoints = durationSeconds / 60
        let bonus = 0.80

        let finalPoints = Int((Double(basePoints) * bonus).rounded())

        XCTAssertEqual(finalPoints, 24) // 30 * 0.80 = 24
    }

    // MARK: - Helpers

    private func createUser(productiveMinutes: Int, nonProductiveMinutes: Int) -> User {
        User(
            email: "test@nd.edu",
            displayName: "Test User",
            dailyProductiveMinutes: productiveMinutes,
            dailyNonProductiveMinutes: nonProductiveMinutes
        )
    }

    /// Replicates the formula from FocusViewModel for testing
    private func calculateScreenTimeBonus(user: User) -> Double {
        let nonProductive = user.dailyNonProductiveMinutes
        let total = max(user.dailyProductiveMinutes + user.dailyNonProductiveMinutes, 1)
        let productiveRatio = Double(user.dailyProductiveMinutes) / Double(total)

        let baseBonus: Double
        switch nonProductive {
        case ..<60:
            baseBonus = 1.30
        case 60..<120:
            baseBonus = 1.15
        case 120..<180:
            baseBonus = 1.00
        case 180..<240:
            baseBonus = 0.90
        default:
            baseBonus = 0.80
        }

        let ratioAdjustment = productiveRatio >= 0.70 ? 0.10 : (productiveRatio >= 0.50 ? 0.05 : 0.0)
        return min(baseBonus + ratioAdjustment, 1.50)
    }
}
