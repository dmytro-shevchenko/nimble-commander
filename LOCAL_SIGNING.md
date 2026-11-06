# Local signing after an unsigned build

Step-by-step guide for developers who build Nimble Commander with `Scripts/build_unsigned.sh` (or equivalent `CODE_SIGNING_ALLOWED=NO` builds), install the app to `/Applications`, and want **macOS Privacy permissions to persist** across launches.

## What was going wrong

| Symptom | Cause |
|--------|--------|
| Downloads / Files and Folders prompts every launch | The unsigned build is **ad-hoc signed**. Each rebuild gets a new code identity, so TCC (Privacy) does not recognize the app as the same program you already allowed. |
| `security find-identity -v -p codesigning` → **0 valid identities** despite a cert in Keychain | The **Apple Development** certificate could not chain to Apple’s current CAs. The system often still had the **expired** pre-2023 WWDR intermediate and was missing **WWDR G3** and **Apple Root CA - G3**. |
| Keychain: development cert **“not trusted”** | Same broken chain—not fixed by setting **Always Trust** on the leaf certificate. |
| `codesign --verify` → Sparkle **“sealed resource is missing or invalid”** | Nested **Sparkle** / **LetsMove** binaries were still ad-hoc, and Sparkle’s old seal referenced SDK **Headers** not shipped in the runtime framework. Re-signing Sparkle rebuilds the seal. |

## What fixed it

1. Installed Apple’s **WWDR G3** and **Apple Root CA - G3** intermediates so **Apple Development** is a valid codesigning identity.
2. After each unsigned build, **manually re-signed** the full app bundle (inside → out), including **Sparkle.framework** and **LetsMove.framework**.
3. Installed the signed app to **`/Applications/Nimble Commander.app`** and re-granted Privacy once for that stable identity.

---

## One-time setup

### 1. Apple Development certificate

1. Open **Xcode → Settings → Accounts** → your Apple ID → **Manage Certificates…**
2. Create **Apple Development** if needed.
3. Confirm in Terminal:

   ```bash
   security find-identity -v -p codesigning
   ```

   You should see one line like:

   ```text
   "Apple Development: your.email@example.com (TEAMID)"
   ```

   Export that exact string (quotes included) as `SIGN_ID` in the steps below.

### 2. Apple CA certificates (if `find-identity` shows 0 identities)

Download and install into the **System** keychain (admin password):

- [AppleWWDRCAG3.cer](https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer)
- [AppleRootCA-G3.cer](https://www.apple.com/certificateauthority/AppleRootCA-G3.cer)

Terminal:

```bash
cd ~/Downloads
curl -LO https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer
curl -LO https://www.apple.com/certificateauthority/AppleRootCA-G3.cer
sudo security add-certificates -k /Library/Keychains/System.keychain \
  AppleWWDRCAG3.cer AppleRootCA-G3.cer
```

Optional: in **Keychain Access → System**, remove the **expired** “Apple Worldwide Developer Relations Certification Authority” (valid 2013–2023).

Set your **Apple Development** cert trust to **Use System Defaults** (not “Always Trust” on the leaf).

Run `security find-identity -v -p codesigning` again until it lists your identity.

---

## After every re-compile (unsigned build)

### Step 1 — Build and install

1. Build (example — works from the repo root or from `Scripts/`):

   ```bash
   ./Scripts/build_unsigned.sh
   ```

   If `./Scripts/build_unsigned.sh` fails copying into an existing `Scripts/Nimble Commander.app`, remove that folder first (it may be an older install with a different Sparkle layout).

2. Mount the generated DMG under `Scripts/`, drag **Nimble Commander** to **Applications** (replace the existing app).
3. Use this path consistently:

   ```text
   /Applications/Nimble Commander.app
   ```

### Step 2 — Set variables

Adjust `SIGN_ID` to match `security find-identity -v -p codesigning`. Paths assume the repo is at `~/IdeaProjects/nimble-commander`.

```bash
export SIGN_ID='Apple Development: your.email@example.com (TEAMID)'
export APP="/Applications/Nimble Commander.app"
export SF="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
export ENT="$HOME/IdeaProjects/nimble-commander/Source/NimbleCommander/NimbleCommander/Resources/NimbleCommander-NonMAS.entitlements"
export HIGHLIGHTER_ENT="$HOME/IdeaProjects/nimble-commander/Source/Viewer/resources/Highlighter.entitlements"
```

### Step 3 — Sign nested binaries (order matters)

**Sparkle** (deepest first):

```bash
codesign --force --options runtime --sign "$SIGN_ID" \
  "$SF/XPCServices/Downloader.xpc/Contents/MacOS/Downloader"
codesign --force --options runtime --sign "$SIGN_ID" \
  "$SF/XPCServices/Downloader.xpc"
codesign --force --options runtime --sign "$SIGN_ID" \
  "$SF/XPCServices/Installer.xpc/Contents/MacOS/Installer"
codesign --force --options runtime --sign "$SIGN_ID" \
  "$SF/XPCServices/Installer.xpc"
codesign --force --options runtime --sign "$SIGN_ID" \
  "$SF/Updater.app/Contents/MacOS/Updater"
codesign --force --options runtime --sign "$SIGN_ID" \
  "$SF/Updater.app"
codesign --force --options runtime --sign "$SIGN_ID" \
  "$SF/Autoupdate"
codesign --force --options runtime --sign "$SIGN_ID" \
  "$SF/Sparkle"
codesign --force --options runtime --sign "$SIGN_ID" \
  "$APP/Contents/Frameworks/Sparkle.framework"
```

**LetsMove**:

```bash
codesign --force --options runtime --sign "$SIGN_ID" \
  "$APP/Contents/Frameworks/LetsMove.framework/Versions/A/LetsMove"
codesign --force --options runtime --sign "$SIGN_ID" \
  "$APP/Contents/Frameworks/LetsMove.framework"
```

**App helpers and main executable**:

```bash
codesign --force --options runtime --sign "$SIGN_ID" \
  --entitlements "$HIGHLIGHTER_ENT" \
  "$APP/Contents/XPCServices/Highlighter.xpc/Contents/MacOS/Highlighter"
codesign --force --options runtime --sign "$SIGN_ID" \
  "$APP/Contents/XPCServices/Highlighter.xpc"
codesign --force --options runtime --sign "$SIGN_ID" \
  "$APP/Contents/Library/LaunchServices/info.filesmanager.Files.PrivilegedIOHelperV2"
codesign --force --options runtime --sign "$SIGN_ID" \
  --entitlements "$ENT" \
  "$APP/Contents/MacOS/Nimble Commander"
codesign --force --options runtime --sign "$SIGN_ID" \
  "$APP"
```

### Step 4 — Verify

```bash
codesign --verify --deep --strict "$APP" && echo "OK"
codesign -dv "$APP" 2>&1 | grep -E 'TeamIdentifier|Signature'
```

Expect **no ad-hoc** signature and a stable **TeamIdentifier** (your personal team). If verify fails on Sparkle, repeat Step 3 for Sparkle before signing the `.app` again.

### Step 5 — Privacy (only when identity changed)

You **do not** need to reset Privacy on every rebuild if you re-sign the **same** installed app with the **same** Apple Development identity.

Reset only when you switch certificates, move to a different copy of the app, or macOS still shows old duplicates:

1. Quit Nimble Commander completely.
2. **System Settings → Privacy & Security** — remove duplicate **Nimble Commander** entries (Files and Folders, Full Disk Access, Accessibility).
3. Launch **`/Applications/Nimble Commander.app`** once and approve prompts.

---

## Optional: avoid manual signing each time

Build **NimbleCommander-NonMAS** from Xcode with **Signing & Capabilities** set to your **Apple Development** team and code signing **enabled** (do not use `CODE_SIGNING_ALLOWED=NO`). Install that product to `/Applications`. You still need the one-time CA setup above if identities were missing.

Upstream release scripts (`build_release.sh`, `build_nightly.sh`) expect the maintainer’s **Developer ID** certificate, not a personal Apple Development cert.

---

## Related notes

| Topic | Detail |
|--------|--------|
| **Full Disk Access vs Accessibility** | “Control this Mac…” is **Accessibility**. It is separate from Full Disk Access. If **Settings → Hotkeys → treat Fn keys as functional** is on, the app may request Accessibility on startup. |
| **Privileged IO helper** | `NimbleCommander-NonMAS-Info.plist` pins `PrivilegedIOHelperV2` to the upstream **Developer ID**. Admin/password helper install may not work with Apple Development signing; that is independent of Files and Folders / Accessibility for the main app. |
| **Launch location** | Always run the same signed copy at **`/Applications/Nimble Commander.app`** so TCC and your workflow stay consistent. |
