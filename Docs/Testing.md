# Testing

Deterministic tests with ScriptedVoiceIO
```swift
import VoiceKitCore
import XCTest

@MainActor
final class ScriptedTests: XCTestCase {
    func testFlow() async throws {
        let data = try! JSONSerialization.data(withJSONObject: ["hello","world"])
        let io = ScriptedVoiceIO(fromBase64: data.base64EncodedString())!
        let r1 = try await io.listen(timeout: 1.5, inactivity: 0.4, record: false)
        XCTAssertEqual(r1.transcript, "hello")
    }
}
```

Package tests (included)
- NameMatchTests: normalization and distance
- ScriptedVoiceIOPackageTests: basic listen flow
- CoreSanityTests: public types reachable

RealVoiceIO tests (app-level)
- Require simulator/device permissions.
- Avoid calling ensurePermissions from non-main contexts.
- Prefer small integration tests; heavy audio verification belongs in manual QA or specialized harnesses.

CI
- Recommended GitHub Actions workflow:
  - macos-latest
  - Build VoiceKit
  - Run package tests
  - (Optional) lint Swift format
