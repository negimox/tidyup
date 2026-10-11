# TidyUp — Software Requirements Specification (SRS)

**Version:** 2.0  
**Date:** 2026-10-10  
**Target:** iOS 26.0+ · Swift 6.2+ · SwiftUI · On-device only  

---

## 1. Project Overview

**TidyUp** is an iPhone-only storage cleaner app that helps users free up device storage by finding duplicate/similar photos, screenshots, large videos, and duplicate contacts — then safely deleting them after explicit user review.

> [!IMPORTANT]
> Everything runs on-device. No photos or contacts leave the phone. No external APIs, no cloud processing, no login required.

### 1.1 Evaluation Criteria (from Assignment Brief)

| # | Criterion | Weight |
|---|---|---|
| 1 | Core loop works end-to-end (scan → review → clean) | Highest |
| 2 | Safe — nothing deleted without user approval | High |
| 3 | Fast, accurate scan on large libraries | High |
| 4 | Polished, usable UI | Medium |
| 5 | Build-vs-skip decisions; effective use of AI tools | Medium |

### 1.2 Scope

**In scope:**
- Storage dashboard with used/free space and per-category savings
- Similar photo detection and grouping
- Screenshot collection with bulk selection
- Large video listing with previews
- Duplicate contact detection with merge/delete
- Review-before-delete safety screen
- Permissions flow (Photos `.readWrite`, Contacts, denied/limited states)
- Own name, logo, and design (not copied from Cleanup reference app)

**Out of scope:**
- Payments, subscriptions, paywalls
- Email cleaning
- Other apps' data/caches/junk files (iOS doesn't allow this)
- Login and cloud sync
- iPad, Watch, Mac versions

**Bonus features (attempt after core loop works):**
1. 🏠 Home screen widget (storage summary)
2. 🎬 Video compression (`AVAssetExportSession`)
3. 📸 Blurry photo detection (Laplacian variance)

---

## 2. Tech Stack

| Area | Choice | Notes |
|---|---|---|
| **Language** | Swift 6.2+, strict concurrency | Per AGENTS.md |
| **UI** | SwiftUI, iOS 26+ | Liquid Glass design language |
| **State management** | `@Observable` view models, `@MainActor` | No `ObservableObject`/`@Published` |
| **Navigation** | `NavigationStack`, `Tab` API | No `NavigationView` or `tabItem()` |
| **Photos** | PhotoKit: `PHAsset`, `PHImageManager`, `PHPhotoLibraryChangeObserver` | |
| **Similarity** | Vision: `VNGenerateImageFeaturePrintRequest` (Revision 2) | Threshold: 0.35 default |
| **Blur detection** | Core Image: `CIConvolution3X3` Laplacian kernel | Variance < 100 = blurry |
| **Contacts** | `CNContactStore`, `CNSaveRequest`, `CNMutableContact` | |
| **Video** | `AVKit` preview, `AVAssetExportSession` compression | |
| **Storage** | `URLResourceValues`: `volumeAvailableCapacityForImportantUsage` | |
| **Cache** | SwiftData: feature prints, scan metadata | |
| **Widget** | WidgetKit: `StaticConfiguration`, `.systemSmall`/`.systemMedium` | |
| **Auth (bonus)** | `LocalAuthentication` (Face ID / passcode vault) | Only if time permits |
| **Tooling** | Xcode 18, GitHub, Figma, AI coding tools | |

**External APIs:** None. Third-party frameworks: None.

---

## 3. Architecture

### 3.1 Pattern: MVVM with `@Observable`

Per the `swift-architecture-skill` selection guide:
- **UI Stack:** SwiftUI only → MVVM is the natural fit
- **iOS 26:** `@Observable` is natively available — no need for `ObservableObject`
- **Scope:** Multi-screen with shared state → MVVM handles this cleanly
- **Complexity:** Medium — no need for TCA, VIPER, or Clean Architecture

### 3.2 Project Structure

```
TidyUp/
├── App/
│   └── TidyUpApp.swift                    // @main, ModelContainer, tab setup
├── Core/
│   ├── Services/
│   │   ├── PhotoScanService.swift          // Vision + PhotoKit scan pipeline
│   │   ├── ContactScanService.swift        // Contact dedup engine
│   │   ├── StorageService.swift            // Device storage queries
│   │   ├── DeletionService.swift           // PHPhotoLibrary deletion + contacts
│   │   └── PermissionService.swift         // Photos + Contacts authorization
│   ├── Models/
│   │   ├── SimilarGroup.swift              // Group of visually similar photos
│   │   ├── ScreenshotItem.swift            // Screenshot asset wrapper
│   │   ├── VideoItem.swift                 // Video with file size metadata
│   │   ├── DuplicateContactGroup.swift     // Group of duplicate contacts
│   │   ├── ScanResult.swift                // Combined scan output
│   │   └── ScanProgress.swift              // Progress enum for AsyncStream
│   └── Cache/
│       └── CachedFeaturePrint.swift        // SwiftData model
├── Features/
│   ├── Dashboard/
│   │   ├── DashboardView.swift
│   │   └── DashboardViewModel.swift
│   ├── SimilarPhotos/
│   │   ├── SimilarPhotosListView.swift
│   │   ├── GroupDetailView.swift
│   │   └── SimilarPhotosViewModel.swift
│   ├── Screenshots/
│   │   ├── ScreenshotsGridView.swift
│   │   └── ScreenshotsViewModel.swift
│   ├── Videos/
│   │   ├── LargeVideosListView.swift
│   │   └── VideosViewModel.swift
│   ├── Contacts/
│   │   ├── DuplicateContactsView.swift
│   │   ├── ContactMergePreviewView.swift
│   │   └── ContactsViewModel.swift
│   ├── Review/
│   │   ├── ReviewDeleteView.swift
│   │   └── ReviewViewModel.swift
│   ├── SpaceFreed/
│   │   └── SpaceFreedView.swift
│   └── Permissions/
│       └── PermissionsPrimerView.swift
├── DesignSystem/
│   ├── Theme.swift                         // Colors, spacing grid, radii
│   ├── StorageRingView.swift               // Animated circular progress
│   ├── CategoryRowView.swift               // Dashboard category card
│   └── SelectionToolbar.swift              // Sticky bottom bar
├── Widget/
│   ├── TidyUpWidget.swift                  // Widget entry point
│   └── StorageWidgetView.swift             // Widget UI
└── Tests/
    ├── PhotoScanServiceTests.swift
    ├── ContactScanServiceTests.swift
    └── StorageServiceTests.swift
```

### 3.3 Data Flow

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐
│  SwiftUI     │────▸│  @Observable │────▸│  Services    │
│  Views       │◂────│  ViewModels  │◂────│  (actors)    │
│  (@State)    │     │  (@MainActor)│     │              │
└─────────────┘     └──────────────┘     └──────────────┘
                                                │
                                         ┌──────┴──────┐
                                         │  SwiftData  │
                                         │  (cache)    │
                                         └─────────────┘
```

- **Views** own ViewModels via `@State`
- **ViewModels** are `@Observable` classes marked `@MainActor`
- **Services** are actors (or nonisolated with internal locking) for thread safety
- **SwiftData** is accessed via `ModelContext` for caching feature prints

---

## 4. Functional Requirements

### 4.1 Permissions Flow

| ID | Requirement |
|---|---|
| PERM-01 | Show explanation screen before requesting any permissions |
| PERM-02 | Request Photos access (`.readWrite`) with clear `NSPhotoLibraryUsageDescription` |
| PERM-03 | Request Contacts access with clear `NSContactsUsageDescription` |
| PERM-04 | Handle `.authorized` → proceed to dashboard |
| PERM-05 | Handle `.limited` → show banner + button calling `PHPhotoLibrary.shared().presentLimitedLibraryPicker()` |
| PERM-06 | Handle `.denied` → explain + deep-link to Settings (`UIApplication.openSettingsURLString`) |
| PERM-07 | Contacts must work when Photos is denied, and vice versa |

### 4.2 Storage Dashboard

| ID | Requirement |
|---|---|
| DASH-01 | Show animated circular progress ring with used vs. free storage |
| DASH-02 | Query `volumeAvailableCapacityForImportantUsage` and `volumeTotalCapacity` |
| DASH-03 | Show total "can free X GB" estimate across all categories |
| DASH-04 | Show 4 category rows: Similar Photos, Screenshots, Large Videos, Duplicate Contacts |
| DASH-05 | Each category row shows item count and estimated savings |
| DASH-06 | Tap category → navigate to that category's review screen |
| DASH-07 | "Scan" button triggers scan with live progress |

### 4.3 Similar Photos Scan

| ID | Requirement |
|---|---|
| SCAN-01 | Fetch all `PHAsset` with `mediaType == .image`, sorted by `creationDate` |
| SCAN-02 | Bucket assets by time window (~10 minutes) to avoid O(n²) comparisons |
| SCAN-03 | Request ~300px thumbnails via `PHImageManager` with `deliveryMode: .fastFormat` |
| SCAN-04 | Set `isNetworkAccessAllowed = false` to skip iCloud-only assets |
| SCAN-05 | Compute Vision feature print per image using `VNGenerateImageFeaturePrintRequest` |
| SCAN-06 | Use `withThrowingTaskGroup` capped at `ProcessInfo.processInfo.activeProcessorCount` |
| SCAN-07 | Compare feature prints within each bucket using `computeDistance(to:)` |
| SCAN-08 | Default similarity threshold: **0.35** (pairs below this distance are "similar") |
| SCAN-09 | Merge similar pairs into groups using union-find algorithm |
| SCAN-10 | Pick "best shot" per group by score: sharpness (Laplacian), resolution, `.favorite` flag |
| SCAN-11 | Cache feature prints in SwiftData (`CachedFeaturePrint`) for instant rescans |
| SCAN-12 | Emit progress via `AsyncStream<ScanProgress>` consumed on `@MainActor` |
| SCAN-13 | Support cancellation: check `Task.checkCancellation()` at each batch boundary |

### 4.4 Screenshots

| ID | Requirement |
|---|---|
| SS-01 | Fetch assets with predicate on `.photoScreenshot` media subtype |
| SS-02 | Display in scrollable grid with multi-select |
| SS-03 | "Select All" / "Deselect All" toggle |
| SS-04 | Show running count and size of selected items |

### 4.5 Large Videos

| ID | Requirement |
|---|---|
| VID-01 | List videos sorted by file size (largest first) via `PHAssetResource` |
| VID-02 | Show thumbnail, duration, and file size per video |
| VID-03 | Tap to preview with `VideoPlayer` from `AVKit` |
| VID-04 | Multi-select for deletion |
| VID-05 | *(Bonus)* Offer compression option via `AVAssetExportSession` |

### 4.6 Duplicate Contacts

| ID | Requirement |
|---|---|
| CON-01 | Fetch all contacts via `CNContactStore` |
| CON-02 | Normalize phone numbers to last 10 digits, lowercase emails |
| CON-03 | Fuzzy-match names using Levenshtein or Jaro-Winkler distance |
| CON-04 | Group matches into `DuplicateContactGroup` |
| CON-05 | **Show merge preview**: let user choose which name/photo to keep |
| CON-06 | Merge into `CNMutableContact` that unions phone numbers and emails |
| CON-07 | Delete extras via `CNSaveRequest` |
| CON-08 | **Warn user**: contact merge is permanent (no "Recently Deleted" safety net) |

### 4.7 Review Before Delete

| ID | Requirement |
|---|---|
| REV-01 | Shared `SelectionStore` (`@Observable`) as single source of truth |
| REV-02 | Show per-category counts and sizes |
| REV-03 | Show total "will free X" estimate |
| REV-04 | Clear safety note: "These items will move to Recently Deleted" |
| REV-05 | Separate warning for contacts: "Contact merges are permanent" |
| REV-06 | Confirm button triggers deletion |

### 4.8 Deletion

| ID | Requirement |
|---|---|
| DEL-01 | Batch all photo/video deletions into single `PHAssetChangeRequest.deleteAssets()` call |
| DEL-02 | iOS system confirmation dialog appears (cannot be suppressed) |
| DEL-03 | Handle: user cancels system dialog, partial failures, stale assets |
| DEL-04 | Contact merges via `CNSaveRequest.delete()` + `CNSaveRequest.add()` |
| DEL-05 | Navigate to "Space Freed" screen on completion |

### 4.9 Space Freed Screen

| ID | Requirement |
|---|---|
| SF-01 | Show "X items moved to Recently Deleted" (not "X GB freed") |
| SF-02 | Explain: "To reclaim storage now, go to Photos → Albums → Recently Deleted → Delete All" |
| SF-03 | Show contact merge count separately: "X contacts merged" |
| SF-04 | Celebratory animation (checkmark, confetti, or similar) with haptic |

---

## 5. Non-Functional Requirements

### 5.1 Performance

| ID | Requirement |
|---|---|
| PERF-01 | Scan 10,000+ photos in under 60 seconds on iPhone 13 or newer |
| PERF-02 | Rescan (with cached feature prints) completes in under 5 seconds |
| PERF-03 | Memory usage stays under 200 MB during scan (use `@autoreleasepool` in batch loops) |
| PERF-04 | UI remains responsive during scan (all heavy work off `@MainActor`) |
| PERF-05 | Thumbnail sizes ≤ 300px to minimize memory during feature print generation |

### 5.2 Safety

| ID | Requirement |
|---|---|
| SAFE-01 | Nothing is deleted without explicit user approval on the Review screen |
| SAFE-02 | iOS system confirmation dialog always shown for photo/video deletions |
| SAFE-03 | Photos go to Recently Deleted (30-day recovery window) |
| SAFE-04 | Contact merge previewed before execution; user must confirm per-group |
| SAFE-05 | App never crashes on permission denial — always gracefully degrades |

### 5.3 Accessibility

| ID | Requirement |
|---|---|
| A11Y-01 | All interactive elements have VoiceOver labels |
| A11Y-02 | Dynamic Type supported (no hardcoded font sizes — use `.title2`, `.body`, `.caption`) |
| A11Y-03 | Light and dark mode both work correctly |
| A11Y-04 | Reduce Motion respected (no gratuitous animations) |
| A11Y-05 | Buttons use `Button("Label", systemImage: "icon")` pattern |

### 5.4 Privacy

| ID | Requirement |
|---|---|
| PRIV-01 | All processing happens on-device |
| PRIV-02 | No network calls, no analytics, no telemetry |
| PRIV-03 | Feature print cache stored locally in app sandbox |
| PRIV-04 | No private photos in screen recording |

---

## 6. Screen Inventory

| # | Screen | Key Components |
|---|---|---|
| 01 | Permissions Primer | Explanation cards, "Allow Access" CTA |
| 02 | Dashboard | Storage ring, category cards, "Scan" button |
| 03 | Similar Photos List | Groups with thumbnail strip, item count |
| 04 | Group Detail | Best shot badged, others pre-selected, toggle selection |
| 05 | Screenshots Grid | Multi-column grid, select all, running count |
| 06 | Large Videos List | Sorted by size, thumbnail + duration + size, preview |
| 07 | Duplicate Contacts | Grouped matches, merge preview, confirm |
| 08 | Review & Delete | Per-category summary, total savings, safety note, confirm CTA |
| 09 | Limited / Denied State | Explanation + deep link to Settings |
| 10 | Space Freed | Success animation, item counts, "Recently Deleted" guidance |

---

## 7. Design System

### 7.1 Colors

| Token | Value | Usage |
|---|---|---|
| `primary` | `#5B5BF0` (Indigo) | Primary actions, accents |
| `bestGreen` | `#16A34A` | "Best shot" badge, keep actions |
| `deleteRed` | `#EF4444` | Delete actions, warnings |
| `photosIndigo` | `#6366F1` | Photos category |
| `screenshotsCyan` | `#06B6D4` | Screenshots category |
| `videosAmber` | `#F59E0B` | Videos category |
| `contactsPink` | `#EC4899` | Contacts category |

**Semantic colors:** Use `Color(.systemBackground)`, `.secondary`, `.tertiary` for backgrounds and text hierarchy. Define custom colors in Asset Catalog with light/dark variants.

### 7.2 Typography

Use **Dynamic Type** text styles — never hardcode font sizes:

| Role | Style | Weight |
|---|---|---|
| Screen titles | `.title2` | `.bold()` |
| Section headers | `.headline` | default |
| Body text | `.body` | default |
| Stats / numbers | `.title` | `.light` via `fontWeight(.light)` |
| Captions | `.caption` | default |

Font: **SF Pro** (system default) — matches Figma's Inter closest.

### 7.3 Spacing Grid (base-4/8)

```
4 · 8 · 12 · 16 · 20 · 24 · 32 · 48
```

- Outer content padding: 16–20pt horizontal
- Between sections: 24–32pt vertical
- Card internal padding: 12–16pt
- Stack spacing: 8–12pt

### 7.4 Corner Radii

| Context | Radius |
|---|---|
| Cards / grouped content | 10pt |
| Sheets / overlays | 16pt |
| Large hero elements | 24pt |

### 7.5 Liquid Glass (iOS 26)

- Tab bar and navigation bar get Liquid Glass automatically
- Dashboard category cards: subtle `.glassEffect(.regular, in: .rect(cornerRadius: 16))`
- CTA buttons: `.buttonStyle(.glassProminent)`
- Wrapped in `GlassEffectContainer` when multiple glass elements coexist

### 7.6 Tab Bar

4 tabs using the `Tab` API (not `tabItem()`):

| Tab | Label | System Image |
|---|---|---|
| Home | "Home" | `house` |
| Clean | "Clean" | `sparkles` |
| Vault | "Vault" | `lock.shield` |
| Settings | "Settings" | `gearshape` |

---

## 8. Data Models

### 8.1 SwiftData Cache

```swift
@Model
final class CachedFeaturePrint {
    @Attribute(.unique) var assetLocalIdentifier: String = ""
    var featurePrintData: Data = Data()
    var creationDate: Date = Date.distantPast
    var assetModificationDate: Date = Date.distantPast
}
```

### 8.2 Runtime Models (not persisted)

```swift
struct SimilarGroup: Identifiable {
    let id: UUID
    var bestAsset: PHAsset
    var otherAssets: [PHAsset]
    var estimatedSavings: Int64  // bytes
}

struct ScreenshotItem: Identifiable {
    let id: String  // PHAsset.localIdentifier
    let asset: PHAsset
    let fileSize: Int64
}

struct VideoItem: Identifiable {
    let id: String
    let asset: PHAsset
    let fileSize: Int64
    let duration: TimeInterval
}

struct DuplicateContactGroup: Identifiable {
    let id: UUID
    var primary: CNContact
    var duplicates: [CNContact]
    var matchReason: MatchReason  // .phone, .email, .name
}
```

---

## 9. Concurrency Strategy

Per `swift-concurrency-pro` and `swift-concurrency-expert` skills:

| Concern | Approach |
|---|---|
| Scan pipeline | `withThrowingTaskGroup` with max concurrency = CPU count |
| Progress | `AsyncStream<ScanProgress>` pushed by service, consumed on `@MainActor` |
| Cancellation | `Task.checkCancellation()` at each batch boundary; user can cancel scan |
| View model isolation | All `@Observable` VMs marked `@MainActor` |
| Services | Actor isolation or `nonisolated` with `Mutex` for internal state |
| No GCD | Zero `DispatchQueue` usage — all async/await |
| Task lifecycle | `Task` stored in VM, cancelled in view's `onDisappear` or `task` modifier |

---

## 10. Risk Matrix

| Risk | Severity | Mitigation |
|---|---|---|
| iCloud-only photos cause slow scans | 🔴 High | `isNetworkAccessAllowed = false`; skip cloud assets; show "X in iCloud" |
| Memory pressure on 10K+ libraries | 🔴 High | `@autoreleasepool` in batch loops; release thumbnails after feature print |
| False-positive similar groups | 🟡 Medium | Default threshold 0.35; pre-mark best shot; user can toggle |
| Contact merge is irreversible | 🟡 Medium | Merge preview screen; per-group confirmation; no bulk "merge all" |
| System delete dialog fatigue | 🟡 Medium | Single batch `deleteAssets()` call → one system dialog total |
| Stale data after library changes | 🟡 Medium | `PHPhotoLibraryChangeObserver` invalidates scan results |
| Overpromising freed space | 🟡 Medium | State "moved to Recently Deleted"; explain manual emptying |
| Strict concurrency errors | 🟡 Medium | `@MainActor` on VMs; actors for services; `sending` params |
| Simulator has no photos | 🟢 Low | Develop on real iPhone from Day 1 |

---

## 11. Testing Strategy

Per `swift-testing` skill:

| Layer | What to Test | Tool |
|---|---|---|
| **Unit** | Feature print distance calculations, union-find grouping, contact normalization, storage formatting | Swift Testing (`@Test`, `#expect`) |
| **Unit** | Scan progress emission, cancellation behavior | Swift Testing with async tests |
| **Integration** | SwiftData cache read/write, permission state handling | Swift Testing with in-memory container |
| **Manual** | Full scan on real device with 1000+ photos; permission flows; light/dark mode | Real iPhone |
| **Manual** | Screen recording for submission (2–3 min walkthrough) | Real iPhone |

---

## 12. Implementation Timeline (5 Days)

| Day | Phase | Hours | Deliverable |
|---|---|---|---|
| **1** | Phase 0: Setup + Phase 1: Permissions & Dashboard | 8h | Xcode project, design system tokens, tab bar, permissions flow, storage ring with real data |
| **2** | Phase 2: Scan Engine | 8h | Vision scan pipeline, time bucketing, union-find, screenshots filter, video sort, contact dedup. SwiftData cache. AsyncStream progress |
| **3** | Phase 3: Review Screens + Phase 4: Delete | 8h | All review screens, group detail, selection UI, review-before-delete, deletion with system dialog, space freed screen |
| **4** | Phase 5: Polish + Phase 6: Bonus (partial) | 6h | Empty states, loading states, haptics, accessibility, dark mode. Blurry photo detection, video compression option |
| **5** | Phase 6: Bonus (rest) + Phase 7: Submission | 4h | Home screen widget, final polish. README, 2–3 min screen recording, 150-word note. Push to repo |

---

## 13. Submission Deliverables

1. **Code repository** — GitHub link to Xcode project
2. **Screen recording** (2–3 min) — walkthrough: dashboard → scan → similar group → screenshots → videos → contacts → review → delete → space freed
3. **Short note** (< 150 words) — tools used, what works, what's missing, hardest problem solved
4. *(Optional)* TestFlight link if Apple Developer Program is available

---

## 14. Agent Skills Utilization Map

| Phase | Skills to Activate |
|---|---|
| Setup & Architecture | `swift-architecture-skill` (MVVM selection), `swiftui-design-principles` (tokens) |
| Permissions & Dashboard | `swiftui-pro` (modern APIs), `swiftui-ui-patterns` (tab bar, navigation) |
| Scan Engine | `swift-concurrency-pro` (TaskGroup), `swift-concurrency-expert` (strict checks), `swiftdata-pro` (cache) |
| Review Screens | `swiftui-view-refactor` (view composition), `swiftui-ui-patterns` (grids, lists) |
| Delete Flow | `swift-concurrency-pro` (async error handling) |
| Polish | `swiftui-liquid-glass` (iOS 26 effects), `swiftui-performance-audit` (profiling), `swiftui-design-principles` (spacing/color audit) |
| Bonus: Widget | `widgets` (timeline provider, families, rendering modes) |
| Bonus: Security | `swift-security-expert` (Face ID vault, if time permits) |
| Pre-submission | `review-swarm` (parallel review), `review-and-simplify-changes` (code quality) |
| Testing | `swift-testing` (Swift Testing patterns, async tests) |

---

## 15. Implementation Progress & Phase Completion Status

### Summary Table

| Phase | Description | Status | Key Deliverables & Artifacts |
|---|---|:---:|---|
| **Phase 0** | Setup & Architecture | ✅ **Completed** | • Xcode project (`TidyUp.xcodeproj`)<br>• Project generator (`scripts/gen_xcodeproj.py`)<br>• App entry point (`TidyUpApp.swift`)<br>• Theme design system tokens (`Theme.swift`)<br>• App-wide Tab architecture (`MainTabView.swift`) |
| **Phase 1** | Permissions & Dashboard | ✅ **Completed** | • Permission manager (`PermissionService.swift`)<br>• Permission primer & deep linking (`PermissionsPrimerView.swift`)<br>• ScenePhase foreground refresh (`TidyUpApp.swift`)<br>• Storage volume queries (`StorageService.swift`)<br>• Storage gauge circle (`StorageRingView.swift`)<br>• Category cards with Liquid Glass (`CategoryRowView.swift`)<br>• Main dashboard coordinator (`DashboardView.swift`, `DashboardViewModel.swift`) |
| **Phase 2** | On-Device Scan Engine | ✅ **Completed** | • Vision feature print scan pipeline (`PhotoScanService.swift`)<br>• Time-window bucketing (10 min) & Union-Find clustering<br>• SwiftData persistence cache (`CachedFeaturePrint.swift`)<br>• Thread-safe preloaded in-memory cache lookup & batch insert<br>• Atomic CheckedContinuation resume guard (`AtomicResumeBox`)<br>• AsyncStream progress streaming (`ScanProgress.swift`)<br>• Duplicate contacts dedup engine (`ContactScanService.swift`) with Jaro-Winkler & phone normalization |
| **Phase 3** | Review Screens | ✅ **Completed** | • Similar photos group browser (`SimilarPhotosListView.swift`)<br>• Best shot highlight & selection (`GroupDetailView.swift`)<br>• Screenshot multi-select grid (`ScreenshotsGridView.swift`)<br>• Large videos list with AVPlayer preview (`LargeVideosListView.swift`)<br>• Duplicate contacts merge list (`DuplicateContactsView.swift`)<br>• Full contact merge diff sheet (`ContactMergePreviewView.swift`)<br>• Sticky bottom action bar (`SelectionToolbar.swift`) |
| **Phase 4** | Safe Deletion Flow | ✅ **Completed** | • Single-batch confirmation screen (`ReviewDeleteView.swift`)<br>• Asynchronous deletion coordinator (`ReviewViewModel.swift`)<br>• PhotoKit batch delete & Contacts merge engine (`DeletionService.swift`)<br>• Celebratory feedback & guidance (`SpaceFreedView.swift`)<br>• UINotificationFeedbackGenerator haptics |
| **Phase 5** | Polish, Accessibility & Liquid Glass | ✅ **Completed** | • iOS 26 Liquid Glass buttons & cards (`.glassEffect`, `.buttonStyle(.glassProminent)`)<br>• VoiceOver accessibility labels & hints on all buttons & cards<br>• Dynamic Type typography across all views<br>• Strict compliance with `AGENTS.md` (no computed property views, dedicated structs) |
| **Phase 6** | Bonus Features | ✅ **Completed** | • 🏠 Home Screen Storage Widget (`TidyUpWidget.swift`, `StorageWidgetView.swift`) supporting `.systemSmall` & `.systemMedium`<br>• 🎬 Video compression engine (`VideoCompressionService.swift`) with `AVAssetExportSession`<br>• 🔒 Biometric Private Vault (`VaultView.swift`) with `LocalAuthentication` & auto-lock |
| **Phase 7** | Verification & Unit Testing | ✅ **Completed** | • Modern Swift Testing suite (`TidyUpTests.swift`) with `@Suite`, `@Test`, `#expect`<br>• Tests for Contact phone normalization, Jaro-Winkler string similarity, Storage capacity metrics, and Model conformance |

