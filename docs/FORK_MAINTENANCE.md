# Fork maintenance ledger

This document tracks how this fork differs from OpenBubbles upstream. It is a
maintenance record for local builds, not an upstream roadmap. Update it whenever
an upstream change is imported, a fork-owned patch is added or removed, or the
`rustpush` submodule pointer changes.

## Repository baseline

The application upstream uses the `rustpush` branch rather than `main` or
`master`.

| Component | Upstream | Maintained ref | Recorded state on 2026-09-20 |
| --- | --- | --- | --- |
| Application | [`OpenBubbles/openbubbles-app`](https://github.com/OpenBubbles/openbubbles-app), branch `rustpush` | `cfilipov/test-pr231` | Upstream tip `eed1b6332`; PR 231 head `ae273e9e6`; fork tip before this ledger update `38364d1fb` |
| RustPush | [`OpenBubbles/rustpush`](https://github.com/OpenBubbles/rustpush), branch `master` | [`cfilipov/rustpush`](https://github.com/cfilipov/rustpush), branch `cfilipov/findmy-location-lookup` | Upstream tip `f35c4ee0`; fork point `a7fab473`; fork tip `2491bd34` |
| Telephony | [`OpenBubbles/telephony_plus`](https://github.com/OpenBubbles/telephony_plus), branch `main` | No fork changes | `5210e940` |

The installed Android test app uses the Alpha application ID
`com.bluebubbles.messaging.alpha` and the display name `OpenBubbles 𝛼`.
Signing material is kept under `.local/signing/`, and device backups are kept
under `.local/backups/`; both are intentionally gitignored. Never add passwords,
registration codes, Apple credentials, message logs, backups, or signing files
to this ledger.

## Imported upstream work

### OpenBubbles PR 231

- Source: [OpenBubbles/openbubbles-app#231](https://github.com/OpenBubbles/openbubbles-app/pull/231),
  "Improve message reliability, media responsiveness, and desktop sign-in."
- State when last checked on 2026-09-05: open draft, not merged, mergeable, and
  last updated on 2026-07-29.
- Application range: `eed1b6332..ae273e9e6` (54 commits).
- RustPush pointer at the PR head: `e5e76919`.
- Local result: applied and retained. The reconnect, delivery-integrity, and
  message-refresh changes have materially improved incoming-message reliability
  on the Android test device.

Do not remove this range merely because upstream has moved. First verify whether
the PR was merged, partially cherry-picked, superseded, or closed without merge.
If upstream absorbs only part of it, record the absorbed commits here and retain
the remaining behavior as fork-owned patches.

## Fork-owned application work

These changes begin after the PR 231 head at `ae273e9e6`.

| Area | Commit(s) | State | Notes |
| --- | --- | --- | --- |
| Android log export, stable Find My lists, and Alpha display name | `7fe8078e5` | Applied | Uses Android-safe export handling, combines known/unknown location entries into stable lists, and renames the Alpha app to `OpenBubbles 𝛼`. |
| Persistent Find My tabs | `6f663c86b` | Applied | Separates Devices, Items, and Friends and preserves expanded-list state while switching tabs. |
| Find My marker selection | `384ed799d` | Applied | Keeps map selection tied to stable entity keys. |
| Find My item report refresh | `fd15ee2a5` | Applied | Advances the RustPush submodule to include accessory report lookup fixes. |
| Find My item battery decoding and UI | `4023388dc`, `bbe8a945b` | Applied | Decodes item battery warnings and displays low-battery state. |
| Find My device and item icons | `046845474` | Applied | Derives Apple-style entity icons from available model and product metadata. |
| Find My charging labels | `5accb23f5` | Applied | Hides normal `charging`/`notcharging` labels while retaining actionable battery warnings. |
| Android 16 KB page-size compatibility | `dfd9c9e45`, `ae64bb5e3`, `c8cba3e8a`, `96c81a90b`, `42674a9e0` | Applied | Rebuilds/alters native dependencies and Rust flags for 16 KB Android devices. |
| Flutter 3.24 native drag compatibility | `26f64a120` | Applied | Restores the required native drag plugins after the dependency changes and fixes the resulting black startup screen. |
| Local signing hygiene | `90dcab0d7` | Applied | Keeps the reusable Alpha signing configuration out of Git. |
| Local device-backup hygiene | `0ca83f8a5` | Applied | Keeps APK, settings, and conversation backups under `.local/backups/` out of Git. |
| Notification timezone initialization | `7cd0811b8` | Testing | Initializes timezone data before startup services and at notification scheduling boundaries so time-based notifications cannot race startup. |
| Failure-only relay notifications | `5ebbb25f8` | Testing | Removes the unconditional pre-renewal relay reminder and clears reminders left by older builds. Actual registration failures and Apple logouts still notify. |
| Audio-message seek controls | `c5176bd02` | Testing | Replaces the unreliable mobile waveform with a stable slider and elapsed/total playback time. |
| Android backup and log sharing | `38364d1fb` | Testing | Saves settings backups through MediaStore, restores one-tap log sharing, and shortens backup snackbars so their Share actions remain visible. |
| Rich-link send retries | `ed030368f` | Testing | Rebuilds move-only Rust rich-link metadata before retrying a send, avoiding disposed-wrapper failures after a confirmation timeout. |
| Attachment upload timeout retry | `b09e21afd` | Testing | Retries one transient MMCS upload timeout with a fresh upload stream before surfacing a failed attachment message. |
| Failed-message retry identity | `850dd1a68` | Testing | Gives manual retries fresh temporary message and attachment GUIDs so an old error bubble and its controller cannot be reused. |
| Sent-attachment reconciliation | `6dc98022e` | Testing | Waits for the uploaded attachment to be reconciled under its attachment GUID before replacing and refreshing the delivered message. |
| Duplicate contact preference | `49f5f7faf` | Testing | Chooses the photo-bearing, richer contact record when Android exposes multiple records for the same sender. |
| Live contact and avatar refresh | `ec8dae47f` | Testing | Updates existing handle objects and avatar widgets after a contact-refresh event. |
| New-sender contact lookup and refresh completion | `2e8aa1794` | Testing | Applies the same normalized address matching and duplicate preference at handle creation as during refresh, updates the cached address book after direct refreshes, and publishes new contact IDs. Unchanged refreshes do not broadcast UI work. |
| Conversation-list contact titles | `80105adbc` | Testing | Observes persisted chat, handle, and contact changes for ordinary and pinned list titles, including an immediate read for retained controllers. Native database regressions cover new contacts, missing UI events, name changes, and contact removal. |
| Find My failure states and bounded retries | `3043d47de` | Testing | Ends initial loading on client-creation failures, retains cached lists, adds manual retry, backs off failed refreshes from 30 seconds to five minutes, and stops polling outside the foreground. |
| Saved map position serialization | `467cdb2ec` | Testing | Serializes the nullable string value rather than its reactive wrapper, fixing settings exports after Find My use. |
| Stable Maps navigation | `c6c8bb86e` | Testing | Keeps the map menu available for direct connections even when the optional item daemon is not ready. Friends/devices do not require that daemon; server-backed and live-sharing capability checks remain unchanged. |
| Apple authentication transport and compatibility | `c96a5b572`, `fc220dddd` | Testing | Advances RustPush and its forked Apple-private-APIs dependency for safe HTTP errors, fresh GrandSlam connections, and consistent remote-anisette authentication identities. |

None of the fork-owned changes in this section has been proposed upstream.

### Contact lookup regression verification

On 2026-10-04, the focused contact suite passed all 14 tests. The native tests
use a temporary ObjectBox store with synthetic contacts and cover a first
message after a direct contact refresh, a known contact resolving an existing
unknown thread, and a saved handle/contact change updating a title without a
chat write or application refresh event. They also verify an unchanged refresh
does not broadcast contact-update events. Analyzer output for the changed files
contains only the existing mutable-widget and deprecated-color warnings.

The follow-up fixes were installed over the existing Alpha package on the
Pixel 11 Pro on 2026-10-04 after verifying matching signing certificates. The
reported thread now shows its saved contact name and avatar in the main list,
existing conversations remain present, and startup completed without a logged
runtime exception. A first message from a different previously unseen contact
has not yet been retested on the physical device.

## Fork-owned RustPush work

The application currently records RustPush commit `f2f169b`. The previously
installed October 4 baseline recorded `2491bd34`.

### Changes imported with PR 231

The PR advanced RustPush from upstream baseline `a7fab473` to `e5e76919` through
the following local range:

`a7fab473..e5e76919`

That range contains the resilient provisioning/anisette changes, public
submodule URL cleanup, and safer IDS alias error handling needed by the imported
application work.

### Find My authentication refresh compatibility

| Repository / commit | Purpose |
| --- | --- |
| Apple-private-APIs `407e6d2` | Checks GrandSlam HTTP status and rejects invalid response envelopes without logging their contents. |
| Apple-private-APIs `b84a25e` | Uses bounded, fresh HTTP/1 connections for GrandSlam, while sharing cookies and preserving normal connection pooling elsewhere. |
| Apple-private-APIs `4206902` | Applies a compatible authentication client profile only to remote-v3 anisette; local providers and provisioning retain their original identities. |
| RustPush `df3e94e` | Pins the authentication transport changes and points the nested submodule at the maintained fork. |
| RustPush `f2f169b` | Keeps PET-backed delegate and escrow request identities consistent with the anisette provider. CloudKit and account-settings request identities are unchanged. |

The nested dependency is now published to
[`cfilipov/apple-private-apis`](https://github.com/cfilipov/apple-private-apis),
branch `cfilipov/findmy-auth-refresh`, and RustPush's `.gitmodules` points there.
It retains the previous dependency baseline; the unrelated upstream account
persistence rewrite has not been imported.

The October 25 log dumps showed repeated `Token missing` failures while
constructing the Friends client, before Devices/Items were attempted. Live
native diagnostics on October 27 showed HTML where a plist was expected. The
first signed in-place update (`20002228`) retained the existing installation and
exposed Apple's more specific `-80045` rejection. Thus fresh connections alone
were not sufficient. The follow-up build (`20002229`) includes the remote-v3
compatibility profile and stable menu entry, but still needs physical-device
authentication and all-three-tabs verification; the phone was disconnected
before this build was ready. Do not describe the compatibility workaround as a
verified field fix yet.

Local verification: 20 focused Flutter tests pass, including settings JSON
round trips, refresh backoff, navigation policy, item batteries and icons.
Eight Apple-private-APIs tests pass with remote-v3 enabled; the real-device
`test_adi` is deliberately excluded. They cover safe parser failures, fresh
connections/cookies, provider-scoped authentication identity, and the existing
provisioning parser. Analyzer output has only existing warnings/deprecations.

The same APK can start failing after working previously because it depends on
Apple's live authentication service. Cached GSA tokens have server-provided
expirations, MobileMe tokens refresh weekly, and restored accounts must obtain
fresh tokens. October reports describe a new server-side rejection of the
remote provider's Android-derived anisette under Mac/iOS authentication
identities. The exact first failing token-expiry event was not captured.

References: [anisette-v3-server issue 61](https://github.com/Dadoum/anisette-v3-server/issues/61),
[xtool connection handling](https://github.com/xtool-org/xtool/pull/247).
The Windows-profile change is a compatibility workaround, not removal of the
public anisette dependency or a guarantee against future Apple changes.

### Removing the public anisette dependency: investigation only

Android builds currently select `RemoteAnisetteProviderV3` and the upstream
default `https://ani.sidestore.io`. The inspected requests send a generated
identifier and opaque ADI provisioning material, not the account username,
password, SRP login proof or account-login tokens. The service still sees the
provisioning exchanges, can generate the corresponding device-authentication
headers, and sees the connecting IP address. This is a trust dependency even
though account authentication goes directly to Apple. No new service has been
introduced by these patches.

The existing iPhone validation relay supplies NAC validation data and device
version information, not anisette headers. These are distinct roles.

Potential replacements, not implemented or configured:

- **Native iPhone generation:** investigate AuthKit on the existing jailbroken
  relay phone. ReProvision demonstrates `AKAppleIDSession` header generation;
  public runtime headers also expose `AKAnisetteProvisioningController`.
  Those references establish a plausible API path, not compatibility with this
  particular iOS build. Probe selector availability, entitlements, and required
  header presence without logging values or erasing/reprovisioning anything.
  ReProvision declares `com.apple.authkit.client.private`; the current relay
  does not. Keep its existing TrollStore container entitlement and relay ID.
- **Native Mac generation:** the dependency already implements local AOSKit
  generation on macOS. A user-owned, authenticated endpoint could remove the
  public anisette service but would require a reachable Mac.
- **Self-hosted v3:** removes the public operator, but not the Android CoreADI
  compatibility issue. It is not equivalent to native Apple-device generation.
- **On-device Android generation:** the loader dependency alone is not a
  working local provider. The alternative ClearADI implementation in this
  checkout contains `todo!()` stubs and cannot safely replace remote-v3 merely
  by changing a feature flag.

Transport is part of the security design: forwarding native anisette headers
through a public TLS-terminating relay without end-to-end encryption would
shift the trust dependency rather than eliminate it. Prefer an authenticated
private connection or an explicitly paired, end-to-end encrypted protocol.
Fetch on demand, cache only within the valid lifetime, bound retries, and do not
silently fall back to a public provider after a private endpoint fails.

Before changing providers, test GSA/PET renewal, MobileMe token availability
(including `searchPartyToken`), escrow/keychain access, all Find My tabs, and
iMessage registration continuity. Do not wipe app data or change the relay ID.
Account reauthentication may be necessary when changing device-authentication
identity; it has not been proven avoidable. No relay changes, new endpoint,
provider migration, or credential changes have been made for this investigation.

References: [ReProvision login implementation](https://github.com/Matchstic/ReProvision/blob/master/Shared/libProvision/Apple%20Services/RPVLoginImpl.m),
[AuthKit controller runtime header](https://github.com/nst/iOS-Runtime-Headers/blob/master/PrivateFrameworks/AuthKit.framework/AKAnisetteProvisioningController.h).

### Find My changes added in this fork

| Commit | State | Purpose |
| --- | --- | --- |
| `2babec7` | Applied | Looks up fresh Find My accessory reports so nearby items can receive current locations. |
| `70c94ac` | Applied | Ignores unknown report keys instead of failing the entire Find My refresh. |

### Asynchronous iMessage payloads

| Commit | State | Purpose |
| --- | --- | --- |
| `0936a83` | Applied | Parses the original IDS command and validates the MMCS descriptor carried by command 104. |
| `2491bd3` | Applied | Downloads command-104 data without attachment decryption, restores the original command, and passes the result through normal message decryption and parsing. |

This is the receive path used by native iMessage audio messages. Malformed
descriptors and failed downloads now return an error without falsely certifying
delivery, preserving the opportunity for Apple to retry the payload. Synthetic
parser tests pass, and repeated native audio messages were received on the
physical Android test device through 2026-09-20.

### Submodule publication

The RustPush divergence is published to
[`cfilipov/rustpush`](https://github.com/cfilipov/rustpush) on branch
`cfilipov/findmy-location-lookup`. The application `.gitmodules` entry points to
that fork, so a recursive clone can resolve the recorded commit `f2f169b`.

In the maintained checkout, use `origin` for `cfilipov/rustpush` and `upstream`
for `OpenBubbles/rustpush`. Fetch both before integrating new upstream work.

Keep RustPush changes in focused commits and advance the parent repository's
submodule pointer in a separate application commit when practical.

## Protocol investigation notes

### Receive asynchronous iMessage payloads, including audio messages

- Reproduction: a native audio message sent at 17:21 Pacific on 2026-09-05 was
  received and decrypted by OpenBubbles but silently discarded.
- Cause: RustPush advertised `supports-audio-messaging-v2` but did not process
  IDS command `104`. The decrypted command-104 body is an MMCS descriptor with
  `mmcs-url`, `mmcs-owner`, and `mmcs-signature-hex`; `oC` contains the original
  command (`100` in the captured incident).
- Upstream status when checked on 2026-09-05: no matching OpenBubbles application
  or RustPush pull request.
- Implementation reference: Beeper's public iMessage implementation labels
  command 104 as `MessageTypeIMessageAsync`, downloads the MMCS payload without
  an attachment decryption key, restores `oC`, and reprocesses the downloaded
  IDS payload. Its AGPL source was used only as protocol reference material; the
  Rust implementation in this SSPL repository was written independently.

References:

- [Beeper command definitions](https://github.com/beeper/imessage/blob/main/imessage/direct/apns/sendmessagepayload.go#L127-L131)
- [Beeper asynchronous-message handler](https://github.com/beeper/imessage/blob/main/imessage/direct/decrypt.go#L735-L760)

## Updating from upstream

Use merge-based updates by default so the commit IDs in this ledger remain
useful. Rebase only when deliberately rewriting the maintenance history.

1. Start with clean application and submodule worktrees.
2. Fetch `upstream/rustpush` in the application repository and `origin/master`
   in the RustPush checkout.
3. Recheck every imported PR's state and whether equivalent commits landed by a
   different route.
4. Review application divergence with:

   ```bash
   git log --left-right --cherry-pick --oneline upstream/rustpush...HEAD
   git diff --stat upstream/rustpush...HEAD
   ```

5. Review RustPush divergence with:

   ```bash
   git -C rustpush log --left-right --cherry-pick --oneline origin/master...HEAD
   git -C rustpush diff --stat origin/master...HEAD
   ```

6. Merge upstream into a temporary integration branch, resolve conflicts by
   behavior rather than by taking one side wholesale, and run focused tests.
7. Build the Alpha APK with the existing signing identity and install it over
   the current Alpha package so application data remains intact.
8. Update the baselines, status tables, verification notes, and submodule pointer
   in this document.

See [`DEVELOPMENT.md`](DEVELOPMENT.md) for the Android toolchain and build
commands and [`DIAGNOSTICS.md`](DIAGNOSTICS.md) for safe log collection.

## Status vocabulary

- **Applied**: present in the maintained build and intended to remain.
- **Planned**: diagnosed or designed but not yet committed.
- **Testing**: implemented locally but not yet accepted as the installed
  baseline.
- **Superseded**: replaced by another fork-owned implementation.
- **Absorbed upstream**: equivalent behavior is verified upstream and the local
  patch has been removed.
