# TidyUp: Storage Cleaner iOS App, Build Plan

AppFactory App Builder Intern selection task. Plan, stack, phases and design.

- **Figma design:** https://www.figma.com/design/ZOhteBeivxgl8g7DQ7dLxn
- **Working name:** TidyUp (rename freely; the brief requires your own name, logo and design)
- **Time:** The brief PDF says 5 days, the email says 3. This plan targets 3 days, with extras only if time remains.

---

## 1. What the brief is testing

| Criterion | What it means |
|---|---|
| Core loop works end to end | Scan, review, clean must work on a real iPhone before anything else |
| Safe | Nothing is deleted without the Review screen and the system confirmation |
| Fast and accurate on a large library | Incremental, cached, concurrent scanning with live progress |
| Polished | Consistent design system; empty, loading, denied and limited states handled |
| Build vs skip decisions, AI use | Short honest note and a README showing tradeoffs |

**Out of scope:** payments, subscriptions, paywalls, email cleaning, other apps' caches or junk (do not promise it), login and cloud sync, iPad, Watch and Mac.

---

## 2. Tech stack (all free, all on-device)

| Area | Choice |
|---|---|
| Language and UI | Swift 5.10+, SwiftUI, iOS 17 minimum, `@Observable` view models, `NavigationStack` |
| Photos | PhotoKit: `PHAsset`, `PHImageManager`, `PHPhotoLibraryChangeObserver` |
| Similarity | Vision `VNGenerateImageFeaturePrintRequest`, plus a dHash perceptual hash fast path for exact duplicates |
| Blur and quality | Core Image, Laplacian variance as a sharpness score |
| Contacts | `Contacts` framework: `CNContactStore`, `CNSaveRequest` |
| Video | `AVKit` preview, `AVAssetExportSession` for compression |
| Storage numbers | `URLResourceValues`: `volumeAvailableCapacityForImportantUsage`, `volumeTotalCapacity` |
| Cache | SwiftData: asset ID, feature print, hash (fast rescans) |
| Bonus | `LocalAuthentication` (vault), WidgetKit (widget), `EventKit` (calendar cleanup) |
| Tooling | Xcode, GitHub, Figma Starter, your AI coding tool |

**External APIs:** none. The "nothing leaves the device" rule rules out cloud APIs, so state that in your note. The only paid item is TestFlight, which needs the Apple Developer Program ($99); skip it and say why if needed.

---

## 3. Phased plan

### Phase 0: Setup (about 2 hours)
- Create the Xcode project and GitHub repo.
- Add `NSPhotoLibraryUsageDescription` and `NSContactsUsageDescription` strings.
- Folders: `Core/` (services), `Features/`, `DesignSystem/`, `Models/`.
- Add design tokens as Swift constants (colors from the Figma tokens board).
- **Output:** app launches with tab bar and an empty dashboard.

### Phase 1: Permissions and storage dashboard (Day 1)
- **Permissions:** explanation screen first, then request Photos (`.readWrite`) and Contacts.
  - `.authorized`: proceed.
  - `.limited`: banner plus a button calling `presentLimitedLibraryPicker`.
  - `.denied`: explain and deep link to Settings.
  - Contacts must work when Photos is denied, and vice versa.
- **Dashboard:** storage ring (used and free), "can free X GB" total, four category rows with counts and sizes.
- **Output:** real device storage numbers; permission states never crash.

### Phase 2: Scan engine, the hard part (Day 1 into Day 2)
- Fetch `PHFetchResult<PHAsset>` sorted by creation date.
- **Similar photos pipeline:**
  1. Bucket assets by time window (about 10 minutes) so the whole library is never compared against itself.
  2. Request about 299px thumbnails and compute a Vision feature print per image, using a `TaskGroup` capped at the CPU count.
  3. Compare prints within each bucket. Pairs under a distance threshold (start near 0.5, tune on your own library) are merged with union-find into groups.
  4. Pick the best shot by score: sharpness, resolution, favorite flag, face quality if time allows.
- **Screenshots:** predicate on `.photoScreenshot` media subtype.
- **Videos:** file size via `PHAssetResource`, sorted descending.
- **Performance:** cache in SwiftData, scan in batches with a progress bar, run off the main thread, keep thumbnails small.
- **Output:** a scan service emitting `SimilarGroup`, `ScreenshotItem`, `VideoItem` with live progress.

### Phase 3: Review screens (Day 2)
- **Similar Photos list and group detail:** best photo badged "Best", the rest pre-selected, tap to toggle, "Keep best" per group.
- **Screenshots:** grid with Select all and bulk selection.
- **Large Videos:** list by size, tap to preview with `VideoPlayer`.
- **Duplicate Contacts:**
  - Normalize phones to the last 10 digits, lowercase emails, fuzzy-match names (Levenshtein or Jaro-Winkler).
  - Group matches; merge into a `CNMutableContact` that unions numbers and emails; delete extras via `CNSaveRequest`.
- **Output:** every category has working selection and a running "will free X" count.

### Phase 4: Review before delete and safe deletion (Day 2 into Day 3)
- Shared `SelectionStore` as the single source of truth feeding the Review screen.
- **Review screen:** per-category counts and sizes, total freed, clear safety note.
- **Deleting:** `PHPhotoLibrary.performChanges { PHAssetChangeRequest.deleteAssets }`. iOS shows its own confirmation and moves items to Recently Deleted for 30 days, so space is only reclaimed once that is emptied. Say this honestly on the "Space freed" screen.
- **Handle:** user cancelling the system dialog, partial failures, stale assets.
- **Output:** scan, review, clean works end to end.

### Phase 5: Polish and edge cases (Day 3 morning)
- Empty states ("No duplicates, nice"), loading skeletons, haptics, light and dark mode.
- Test on a large real library; keep private photos out of the recording.
- Verify `PHPhotoLibraryChangeObserver` refreshes results after deletions.

### Phase 6: Bonus (only after the core loop is solid)
1. "Space freed" summary (cheap).
2. Blurry photo detection (reuse the Laplacian score).
3. Swipe-to-keep-or-delete mode.
4. Video compression.
5. PIN or Face ID vault, home-screen widget, calendar cleanup, TestFlight.

### Phase 7: Submission (Day 3 afternoon)
- **README:** features, architecture, decisions, known gaps.
- **Screen recording (2 to 3 min):** dashboard, scan, one similar group, screenshots, videos, contacts, review, delete, freed screen.
- **Note (under 150 words):** tools used, what works, what is missing, hardest problem solved (likely fast, accurate similarity at scale).
- Send repo link, recording and note to the email address in the brief.

---

## 4. Design system and Figma contents

- **Color:** primary indigo `#5B5BF0`, keep/best green `#16A34A`, delete red `#EF4444`. Category colors: photos indigo `#6366F1`, screenshots cyan `#06B6D4`, videos amber `#F59E0B`, contacts pink `#EC4899`. Background `#F5F6FA`, ink `#0F172A`, muted `#64748B`.
- **Type:** Inter in Figma, SF Pro on device. Title 22 Bold, body 15, caption 12.
- **Layout:** 20pt margins, corner radii 12/16/24, 4-tab bar (Home, Clean, Vault, Settings).
- **Reference pattern:** dashboard of categories, card-based review per category, sticky bottom CTA. Layout, copy and colors are original, not copied from Cleanup.

| # | Screen |
|---|---|
| 01 | Permissions primer |
| 02 | Dashboard |
| 03 | Similar Photos list |
| 04 | Group detail |
| 05 | Screenshots grid |
| 06 | Large Videos |
| 07 | Duplicate Contacts |
| 08 | Review & Delete |
| 09 | Limited / Denied state |
| 10 | Space Freed |

Note: the Figma layouts are absolutely positioned with placeholder color blocks for photos. Convert to auto-layout, components and variables before developer handoff.

---

## 5. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Slow scan on big libraries | Time bucketing, small thumbnails, concurrent processing, caching |
| False-positive similar groups | Tune threshold, pre-mark the best shot, let users toggle |
| Accidental deletion | Mandatory Review screen, iOS confirmation, 30-day Recently Deleted window |
| Simulator has no photos | Develop on a real iPhone from Day 1 |
| Overpromising freed space | State clearly that space returns after Recently Deleted is emptied |
