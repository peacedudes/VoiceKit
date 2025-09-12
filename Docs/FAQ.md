# FAQ

Q: “BUG IN CLIENT OF LIBDISPATCH: Block was expected to execute on queue […]”
- Cause: @MainActor closures passed to permission APIs (TCC) that callback on background queues.
- Fix: Use the provided PermissionBridge (nonisolated) and await continuations.

Q: “Sending 'utterance' risks causing data races”
- Fix: The delegate copies strings and uses ObjectIdentifier(utterance) before hopping to @MainActor; update to the latest VoiceIO.swift.

Q: “Ambiguous use of ScriptedVoiceIO.init(fromBase64:)”
- Cause: Duplicate type in app and package.
- Fix: Remove the app’s ScriptedVoiceIO from Target Membership; use the package type.

Q: Picker types not found (TTSVoiceProfile etc.)
- Cause: App compiling an old in-app picker.
- Fix: Use VoiceKitUI’s picker and import VoiceKitUI.

Q: Local vs remote package?
- During active dev, use local path (fastest).
- For releases, tag and point your app to the remote GitHub dependency. You can switch back to local later.

Q: Minimum OS / Swift?
- iOS 17.0+, macOS 14.0+, Swift 6 language mode.

Q: Where is the version defined?
- SPM uses git tags. If you need a runtime constant, add VoiceKitInfo.version in VoiceKitCore.
