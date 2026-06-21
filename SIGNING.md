# Signing & notarizing Simmer for distribution

**Why this matters:** without it, anyone who downloads Simmer hits a scary
"Apple could not verify this app is free of malware" block and can't open it
normally. To distribute to other people you must sign with a **Developer ID**
certificate and **notarize** with Apple.

**This needs YOUR Apple account — I can't do it for you.** It costs **$99/year**
(Apple Developer Program). This is the one genuine recurring cost behind the
"free with donations" model.

## One-time setup

1. Enroll in the [Apple Developer Program](https://developer.apple.com/programs/) ($99/yr).
2. In Xcode → Settings → Accounts, add your Apple ID and let it create a
   **Developer ID Application** certificate (Manage Certificates → +).
3. Create an app-specific password for notarization at appleid.apple.com, and
   store credentials once:
   ```sh
   xcrun notarytool store-credentials "simmer-notary" \
     --apple-id "you@example.com" --team-id "YOURTEAMID" \
     --password "app-specific-password"
   ```

## Build → sign → notarize → staple

```sh
# 1. Archive a Release build
xcodebuild -project Simmer.xcodeproj -scheme Simmer -configuration Release \
  -archivePath build/Simmer.xcarchive archive

# 2. Export with Developer ID signing (needs an ExportOptions.plist with
#    method = developer-id and your team id)
xcodebuild -exportArchive -archivePath build/Simmer.xcarchive \
  -exportPath build/export -exportOptionsPlist ExportOptions.plist

# 3. Zip and notarize
ditto -c -k --keepParent build/export/Simmer.app build/Simmer.zip
xcrun notarytool submit build/Simmer.zip --keychain-profile "simmer-notary" --wait

# 4. Staple the ticket so it works offline
xcrun stapler staple build/export/Simmer.app
```

## Notes

- Notarization requires **Hardened Runtime ON**. Simmer currently has it **OFF**
  (so the keystroke/Apple Events feature works in dev). For a notarized build,
  turn `ENABLE_HARDENED_RUNTIME = YES` back on and add the entitlement
  `com.apple.security.automation.apple-events` so "Quick reply" still works.
  (Local dev/ad-hoc builds don't need this.)
- Distribute the stapled `.app` in a `.dmg` or `.zip`, via GitHub Releases or a
  Homebrew cask.

## Status
Not done — requires the Apple Developer account. Everything else is ready.
