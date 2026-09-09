import Foundation

let filter = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : nil

let suites: [(name: String, run: () throws -> Void)] = [
    ("LZWProbe", testLZWProbe),
    ("ANIReader", testANIReaderParsesHeaderRateAndSeq),
    ("ANIReaderRejectsNonRIFF", testANIReaderRejectsNonRIFF),
    ("CURDecoder32bpp", testDecodes32bppRoundTrip),
    ("CURDecoderCorrupt", testRejectsCorrupt),
    ("ANIDocDefaultDuration", testDefaultDurationAndIdentityOrder),
    ("ANIDocRateWins", testRateChunkWins),
    ("ANIDocSeqDuplicates", testSeqExpandsWithDuplicates),
    ("ANIDocTooManyFrames", testTooManyFramesThrows),
    ("ANIDocMismatchedSize", testMismatchedFrameSizeThrows),
    ("ANIDocBadSeq", testBadSeqThrows),
    ("CapeEnvelope", testEnvelopeProducesXMLPlistWithExpectedKeys),
    ("CapeWriterStrip", testStripIsFramesStackedTopToBottomAndTiffLZW),
    ("CapeWriterWrite", testWriteProducesReadableXMLFile),
    ("RoleMapEnglish", testEnglishNames),
    ("RoleMapChinese", testChineseNames),
    ("RoleMapSkipped", testSkippedRolesReturnNil),
    ("RoleMapUnknown", testUnknownReturnsNil),
    ("RoleMapIdentifier", testExplicitIdentifierPassesThrough),
    ("ConverterStacking", testCapeCursorStackingUsesDisplayIndices),
    ("ConverterSlug", testSlugStripsNonAlphanumerics),
    ("ConverterPack", testPackSkipsUnknownAndSubdirsAndWritesCape),
]

var ranAny = false
for suite in suites {
    if let filter, !suite.name.localizedCaseInsensitiveContains(filter) { continue }
    ranAny = true
    print("## \(suite.name)")
    do { try suite.run() }
    catch { Harness.check(false, "suite \(suite.name) threw \(error)") }
}
if !ranAny { print("no suite matched filter: \(filter ?? "")") }
let ok = Harness.summary()
exit(ok ? 0 : 1)
