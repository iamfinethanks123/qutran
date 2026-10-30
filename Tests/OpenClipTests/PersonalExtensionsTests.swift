import XCTest
@testable import OpenClip
@testable import Core

/// Loads the bundled PersonalExtensions packages through the real manifest pipeline.
final class PersonalExtensionsTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() async throws {
        let repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        // Under the repo's build.noindex/ (no symlinked components): the module loader's containment check
        // compares canonical paths, which a /var -> /private/var temp dir trips.
        tempDir = repoRoot.appendingPathComponent("build.noindex/personal-ext-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let source = repoRoot.appendingPathComponent("PersonalExtensions")
        for package in try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil) {
            try FileManager.default.copyItem(at: package, to: tempDir.appendingPathComponent(package.lastPathComponent))
        }
        await MainActor.run {
            // No settings store: skip the trust gate, which the app satisfies by enabling these packages on install.
            ExtensionManager.shared.reset()
            ExtensionManager.shared.actionFactory = DefaultActionFactory(optionStore: SecretActionOptionStore(), isSelectionCurrent: { _ in true })
        }
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        await MainActor.run { ExtensionManager.shared.reset() }
    }

    @MainActor
    func testBundledPackagesLoadEveryAction() async throws {
        await ExtensionManager.shared.loadExtensions(from: tempDir)
        let ids = Set(ExtensionManager.shared.loadedActions.map(\.id))

        for id in ["personal.search.sites", "personal.search.sites.google", "personal.search.sites.cambridge"] {
            XCTAssertTrue(ids.contains(id), "missing \(id)")
        }
        let tools = ["fixLineBreaks", "countText", "upper", "lower", "titleCase", "snakeCase", "camelCase"]
            .map { "personal.texttools.text.\($0)" }
        let codecs = ["formatJSON", "minifyJSON", "base64Encode", "base64Decode", "urlEncode", "urlDecode"]
            .map { "personal.texttools.encode.\($0)" }
        for id in tools + codecs {
            XCTAssertTrue(ids.contains(id), "missing \(id)")
        }
    }

    @MainActor
    func testTextToolRunsInJavaScriptCore() async throws {
        await ExtensionManager.shared.loadExtensions(from: tempDir)
        let action = try XCTUnwrap(ExtensionManager.shared.loadedActions.first { $0.id == "personal.texttools.encode.base64Encode" })
        let context = ActionContext(selection: SelectionContext(text: "繁體中文 😀"))
        let result = try await action.perform(context)
        let text: String?
        switch result {
        case .text(let value), .paste(let value), .copy(let value): text = value
        default: text = nil
        }
        XCTAssertEqual(text, Data("繁體中文 😀".utf8).base64EncodedString())
    }
}
