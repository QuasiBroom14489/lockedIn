import Foundation
import SwiftUI

enum Dorm: String, CaseIterable, Codable, Identifiable {
    // Men's Dorms
    case carroll
    case dillon
    case duncan
    case fisher
    case keenan
    case keough
    case knott
    case morrissey
    case oneill
    case siegfried
    case sorin
    case stEdwards
    case stanford
    case coyle

    // Women's Dorms
    case badin
    case breenPhillips
    case cavanaugh
    case farley
    case howard
    case lewis
    case lyons
    case mcglinn
    case pasquerillaEast
    case pasquerillaWest
    case ryan
    case walsh
    case welshFamily

    // Co-ed / Other
    case gateway

    var id: String { rawValue }

    // MARK: - Display Properties

    var displayName: String {
        switch self {
        case .carroll: return "Carroll Hall"
        case .dillon: return "Dillon Hall"
        case .duncan: return "Duncan Hall"
        case .fisher: return "Fisher Hall"
        case .keenan: return "Keenan Hall"
        case .keough: return "Keough Hall"
        case .knott: return "Knott Hall"
        case .morrissey: return "Morrissey Manor"
        case .oneill: return "O'Neill Hall"
        case .siegfried: return "Siegfried Hall"
        case .sorin: return "Sorin College"
        case .stEdwards: return "St. Edward's Hall"
        case .stanford: return "Stanford Hall"
        case .coyle: return "Coyle Hall"
        case .badin: return "Badin Hall"
        case .breenPhillips: return "Breen-Phillips Hall"
        case .cavanaugh: return "Cavanaugh Hall"
        case .farley: return "Farley Hall"
        case .howard: return "Howard Hall"
        case .lewis: return "Lewis Hall"
        case .lyons: return "Lyons Hall"
        case .mcglinn: return "McGlinn Hall"
        case .pasquerillaEast: return "Pasquerilla East"
        case .pasquerillaWest: return "Pasquerilla West"
        case .ryan: return "Ryan Hall"
        case .walsh: return "Walsh Hall"
        case .welshFamily: return "Welsh Family Hall"
        case .gateway: return "Gateway"
        }
    }

    var shortName: String {
        switch self {
        case .carroll: return "Carroll"
        case .dillon: return "Dillon"
        case .duncan: return "Duncan"
        case .fisher: return "Fisher"
        case .keenan: return "Keenan"
        case .keough: return "Keough"
        case .knott: return "Knott"
        case .morrissey: return "Morrissey"
        case .oneill: return "O'Neill"
        case .siegfried: return "Siegfried"
        case .sorin: return "Sorin"
        case .stEdwards: return "St. Ed's"
        case .stanford: return "Stanford"
        case .coyle: return "Coyle"
        case .badin: return "Badin"
        case .breenPhillips: return "BP"
        case .cavanaugh: return "Cavanaugh"
        case .farley: return "Farley"
        case .howard: return "Howard"
        case .lewis: return "Lewis"
        case .lyons: return "Lyons"
        case .mcglinn: return "McGlinn"
        case .pasquerillaEast: return "PE"
        case .pasquerillaWest: return "PW"
        case .ryan: return "Ryan"
        case .walsh: return "Walsh"
        case .welshFamily: return "Welsh Fam"
        case .gateway: return "Gateway"
        }
    }

    // MARK: - Icons (SF Symbols)

    var icon: String {
        switch self {
        case .carroll: return "c.circle.fill"
        case .dillon: return "shield.fill"
        case .duncan: return "building.2.fill"
        case .fisher: return "fish.fill"
        case .keenan: return "bolt.fill"
        case .keough: return "k.circle.fill"
        case .knott: return "k.square.fill"
        case .morrissey: return "house.fill"
        case .oneill: return "o.circle.fill"
        case .siegfried: return "crown.fill"
        case .sorin: return "building.columns.fill"
        case .stEdwards: return "cross.fill"
        case .stanford: return "s.circle.fill"
        case .coyle: return "c.square.fill"
        case .badin: return "b.circle.fill"
        case .breenPhillips: return "b.square.fill"
        case .cavanaugh: return "star.fill"
        case .farley: return "f.circle.fill"
        case .howard: return "bird.fill"
        case .lewis: return "l.circle.fill"
        case .lyons: return "cat.fill"
        case .mcglinn: return "leaf.fill"
        case .pasquerillaEast: return "arrow.right.circle.fill"
        case .pasquerillaWest: return "arrow.left.circle.fill"
        case .ryan: return "r.circle.fill"
        case .walsh: return "w.circle.fill"
        case .welshFamily: return "figure.2.and.child.holdinghands"
        case .gateway: return "door.left.hand.open"
        }
    }

    // MARK: - Colors

    var color: Color {
        switch self {
        case .carroll: return Color(hex: "4A90A4")
        case .dillon: return Color(hex: "CC0000")
        case .duncan: return Color(hex: "6B8E23")
        case .fisher: return Color(hex: "228B22")
        case .keenan: return Color(hex: "4169E1")
        case .keough: return Color(hex: "708090")
        case .knott: return Color(hex: "8B4513")
        case .morrissey: return Color(hex: "800000")
        case .oneill: return Color(hex: "2E8B57")
        case .siegfried: return Color(hex: "FFD700")
        case .sorin: return Color(hex: "C7A32E")
        case .stEdwards: return Color(hex: "4B0082")
        case .stanford: return Color(hex: "DC143C")
        case .coyle: return Color(hex: "008B8B")
        case .badin: return Color(hex: "9932CC")
        case .breenPhillips: return Color(hex: "FF69B4")
        case .cavanaugh: return Color(hex: "FF6347")
        case .farley: return Color(hex: "20B2AA")
        case .howard: return Color(hex: "FFD700")
        case .lewis: return Color(hex: "00CED1")
        case .lyons: return Color(hex: "9370DB")
        case .mcglinn: return Color(hex: "00843D")
        case .pasquerillaEast: return Color(hex: "FF4500")
        case .pasquerillaWest: return Color(hex: "1E90FF")
        case .ryan: return Color(hex: "B22222")
        case .walsh: return Color(hex: "DAA520")
        case .welshFamily: return Color(hex: "7B68EE")
        case .gateway: return Color(hex: "5C6BC0")
        }
    }

    var gradientColors: [Color] {
        [color, color.opacity(0.7)]
    }

    // MARK: - Gender Classification

    var isMensDorm: Bool {
        switch self {
        case .carroll, .dillon, .duncan, .fisher, .keenan, .keough, .knott,
             .morrissey, .oneill, .siegfried, .sorin, .stEdwards, .stanford, .coyle:
            return true
        default:
            return false
        }
    }

    var isWomensDorm: Bool {
        switch self {
        case .badin, .breenPhillips, .cavanaugh, .farley, .howard, .lewis,
             .lyons, .mcglinn, .pasquerillaEast, .pasquerillaWest, .ryan, .walsh, .welshFamily:
            return true
        default:
            return false
        }
    }

    // MARK: - Grouped Lists

    static var mensDorms: [Dorm] {
        allCases.filter { $0.isMensDorm }.sorted { $0.displayName < $1.displayName }
    }

    static var womensDorms: [Dorm] {
        allCases.filter { $0.isWomensDorm }.sorted { $0.displayName < $1.displayName }
    }

    static var otherDorms: [Dorm] {
        allCases.filter { !$0.isMensDorm && !$0.isWomensDorm }.sorted { $0.displayName < $1.displayName }
    }

    // MARK: - String Matching

    static func from(string: String?) -> Dorm? {
        guard let string = string?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
              !string.isEmpty else { return nil }

        // Direct rawValue match
        if let dorm = Dorm(rawValue: string) {
            return dorm
        }

        // Match by display name or short name
        return allCases.first { dorm in
            dorm.displayName.lowercased() == string ||
            dorm.shortName.lowercased() == string ||
            dorm.displayName.lowercased().contains(string) ||
            string.contains(dorm.shortName.lowercased())
        }
    }
}

// MARK: - Preview Helpers

extension Dorm {
    static var previewDorms: [Dorm] {
        [.dillon, .sorin, .lyons, .mcglinn, .gateway]
    }
}
