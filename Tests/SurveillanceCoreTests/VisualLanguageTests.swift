import Testing
@testable import SurveillanceCore

@Test func visualLanguageEncodesSalienceAndRolePalette() throws {
    let language = try VisualLanguage.bundled()
    #expect(language.salience.map(\.rank) == Array(1...9))
    #expect(language.salience[0].surface == "player")
    #expect(language.spriteBoxes["playerAndStandardEnemy"] == AssetDimensions(width: 64, height: 64))
    #expect(language.spriteBoxes["algorithmicModerate"] == AssetDimensions(width: 96, height: 96))
    #expect(language.atlases.count == 8)
    #expect(language.colorIsNotSoleCarrier)
    #expect(language.collisionNeverFromSpriteBounds)
}

@Test func visualLanguageUnknownSchemaFailsClosed() throws {
    let json = #"{"schemaVersion":"visual-language-000"}"#.data(using: .utf8)!
    do {
        _ = try VisualLanguageLoader.decode(json)
        Issue.record("expected schema failure")
    } catch VisualLanguageError.schemaVersion {
    }
}
