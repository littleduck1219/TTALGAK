import AppKit
import SpearGameCore

private struct MotionManifest: Decodable {
    struct Artboard: Decodable { struct Units: Decodable { let width: Int; let height: Int }; let logicalUnits: Units }
    struct Contact: Decodable { let hand: [Double]; let tail: [Double]; let tangent: [Double]; let ballisticP0: [Double]? }
    struct Sequence: Decodable { let frameOrder: [String]; let contact: Contacts }
    struct Contacts: Decodable { let final: Contact }
    struct Sequences: Decodable { let durationMs: Int; let low25: Sequence; let mid45: Sequence; let high65: Sequence }
    let artboard: Artboard
    let releaseSweepSequences: Sequences
}

/// Loads only bundled internal assets. Any decode, resource, or continuity failure returns nil and preserves the code-drawn actor.
final class StickmanMotionAssets {
    private let bundle: Bundle
    private let manifest: MotionManifest

    init?(bundle: Bundle = .module) {
        guard let url = bundle.url(forResource: "asset-manifest", withExtension: "json", subdirectory: "StickmanMotion"),
              let decoded = try? JSONDecoder().decode(MotionManifest.self, from: Data(contentsOf: url)),
              decoded.artboard.logicalUnits.width == 180, decoded.artboard.logicalUnits.height == 110,
              decoded.releaseSweepSequences.durationMs == 160 else { return nil }
        self.bundle = bundle
        self.manifest = decoded
        guard MotionAssetBand.allCases.allSatisfy({ validate($0) }) else { return nil }
    }

    func image(named name: String) -> NSImage? {
        guard let url = bundle.url(forResource: name.replacingOccurrences(of: ".png", with: ""), withExtension: "png", subdirectory: "StickmanMotion/runtime") else { return nil }
        return NSImage(contentsOf: url)
    }

    func snapshot(for band: MotionAssetBand, in view: NSView) -> MotionAssetSnapshot? {
        let contact = sequence(for: band).contact.final
        guard contact.hand.count == 2, contact.tail == contact.hand, contact.ballisticP0 == contact.hand, contact.tangent.count == 2 else { return nil }
        let local = NSPoint(x: contact.ballisticP0![0], y: 110 - contact.ballisticP0![1])
        // `local` is view space; convert through the owning window before requesting screen space.
        guard let window = view.window else { return nil }
        let windowPoint = view.convert(NSRect(origin: local, size: .zero), to: nil).origin
        let screen = window.convertToScreen(NSRect(origin: windowPoint, size: .zero)).origin
        return MotionAssetSnapshot(band: band, finalP0: PresentationPoint(x: screen.x, y: screen.y), flightStart: PresentationPoint(x: screen.x, y: screen.y), flightTangentYUp: PresentationPoint(x: contact.tangent[0], y: -contact.tangent[1]), usesCodeFallback: false)
    }

    private func validate(_ band: MotionAssetBand) -> Bool {
        let sequence = sequence(for: band)
        let expected = band.releaseFiles.map { $0.replacingOccurrences(of: ".png", with: ".svg") }
        let final = sequence.contact.final
        return sequence.frameOrder == expected && final.hand == final.tail && final.ballisticP0 == final.hand && final.tangent.count == 2 &&
            (["ready.png", band.aimFile, "recovery.png"] + band.releaseFiles).allSatisfy { image(named: $0) != nil }
    }

    private func sequence(for band: MotionAssetBand) -> MotionManifest.Sequence {
        switch band { case .low25: return manifest.releaseSweepSequences.low25; case .mid45: return manifest.releaseSweepSequences.mid45; case .high65: return manifest.releaseSweepSequences.high65 }
    }
}
