import Foundation

/// General care tips per medium, shown on listings and in the care guide.
/// Artists can add their own note, which buyers see first.
struct CareTip: Hashable, Identifiable {
    let icon: String
    let text: String
    var id: String { text }
}

enum CareGuide {
    static let maxNoteLength = 300

    static func tips(for medium: ArtworkMedium) -> [CareTip] {
        switch medium {
        case .oilOnCanvas:
            return [
                CareTip(icon: "sun.max", text: "Hang out of direct sunlight to keep colours bright."),
                CareTip(icon: "paintbrush", text: "Dust with a soft, dry brush. Avoid cloths, water and sprays."),
                CareTip(icon: "thermometer.medium", text: "Keep away from radiators, fireplaces and damp walls."),
                CareTip(icon: "hand.raised", text: "Lift by the frame or stretcher, never the painted surface.")
            ]
        case .acrylic:
            return [
                CareTip(icon: "sun.max", text: "Hang out of direct sunlight to keep colours bright."),
                CareTip(icon: "paintbrush", text: "Dust with a soft, dry brush. No cloths or sprays."),
                CareTip(icon: "drop", text: "Keep away from damp walls, kitchens and bathrooms."),
                CareTip(icon: "hand.raised", text: "Lift by the frame or stretcher, not the painted surface.")
            ]
        case .watercolor:
            return [
                CareTip(icon: "sun.max", text: "Keep out of direct sunlight; watercolours fade fastest."),
                CareTip(icon: "rectangle.on.rectangle", text: "Frame behind UV-filtering glass with an acid-free mount."),
                CareTip(icon: "drop", text: "Hang away from humidity to stop the paper rippling."),
                CareTip(icon: "hand.raised", text: "Handle unframed works by the edges with clean, dry hands.")
            ]
        case .pastel:
            return [
                CareTip(icon: "rectangle.on.rectangle", text: "Keep framed under glass with a spacer so nothing touches the surface."),
                CareTip(icon: "hand.raised", text: "Never touch or brush the surface; pastel smudges easily."),
                CareTip(icon: "arrow.up.and.down", text: "Carry and store it flat and upright, without knocks."),
                CareTip(icon: "sun.max", text: "Hang out of direct sunlight and away from damp.")
            ]
        case .digital:
            return [
                CareTip(icon: "sun.max", text: "Hang out of direct sunlight to stop the print fading."),
                CareTip(icon: "rectangle.on.rectangle", text: "Frame behind UV-filtering glass for the longest life."),
                CareTip(icon: "drop", text: "Keep away from moisture and steam."),
                CareTip(icon: "hand.raised", text: "Handle unframed prints by the edges, ideally with cotton gloves.")
            ]
        case .mixedMedia:
            return [
                CareTip(icon: "sun.max", text: "Hang out of direct sunlight to protect every layer."),
                CareTip(icon: "paintbrush", text: "Dust gently with a soft, dry brush. No liquids."),
                CareTip(icon: "thermometer.medium", text: "Keep temperature and humidity steady so layers stay bonded."),
                CareTip(icon: "hand.raised", text: "Hold by the edges or frame; raised parts can be fragile.")
            ]
        case .sculpture:
            return [
                CareTip(icon: "cube", text: "Place on a stable, level surface away from busy walkways."),
                CareTip(icon: "paintbrush", text: "Dust with a soft brush or dry microfibre cloth."),
                CareTip(icon: "drop", text: "Avoid water, polish and cleaning products unless the artist advises."),
                CareTip(icon: "hand.raised", text: "Lift from the base with both hands, never by thin parts.")
            ]
        case .photography:
            return [
                CareTip(icon: "sun.max", text: "Hang out of direct sunlight to prevent fading."),
                CareTip(icon: "rectangle.on.rectangle", text: "Frame behind UV-filtering glass with an acid-free mount."),
                CareTip(icon: "drop", text: "Keep away from humidity and steam."),
                CareTip(icon: "hand.raised", text: "Hold prints by the edges; fingerprints mark the surface.")
            ]
        case .printmaking:
            return [
                CareTip(icon: "sun.max", text: "Keep out of direct sunlight to protect the inks and paper."),
                CareTip(icon: "rectangle.on.rectangle", text: "Frame with acid-free mounts and UV-filtering glass."),
                CareTip(icon: "drop", text: "Hang away from damp to prevent foxing and rippling."),
                CareTip(icon: "hand.raised", text: "Handle unframed prints by the margins with clean hands.")
            ]
        case .drawing:
            return [
                CareTip(icon: "rectangle.on.rectangle", text: "Keep framed under glass; graphite and charcoal smudge."),
                CareTip(icon: "sun.max", text: "Hang out of direct sunlight to stop the paper yellowing."),
                CareTip(icon: "drop", text: "Keep away from humidity and damp walls."),
                CareTip(icon: "hand.raised", text: "Never touch the drawn surface; hold by the edges.")
            ]
        }
    }

    /// Cleans an artist's care note for saving: trimmed and capped.
    static func cleanNote(_ text: String) -> String {
        String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxNoteLength))
    }
}
