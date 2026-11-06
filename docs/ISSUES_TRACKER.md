# MedWise — Comprehensive Issue Tracking & Remediation Log

> **Context:** Post-Testing Feedback & App Polish Sprint  
> **Status:** Active Execution (One-by-One Remediation with User Gatekeeper)  
> **Rule:** Resolve issues strictly one-by-one. Report root cause, code changes, redundant code removal, and verification status. Await user confirmation ("yes") before proceeding to the next issue.

---

## 📋 Master Issue Tracker

| # | Issue Summary | Status | Category |
|---|---|---|---|
| **1** | Remove "Estimated Pharmacy Savings" ticker and related UI | 🟢 **Completed** | UI Simplification / Feature Removal |
| **2** | Overall UI visual overhaul & polish (elevate from generic to premium healthcare aesthetic) | 🟢 **Completed** | UI / Design System |
| **3** | Fix pixel overflow on 2:00 AM Quick Finder dialog | 🟢 **Completed** | Bug / Responsive UI |
| **4** | Remove "Demo Data" button and static seed stash | 🟢 **Completed** | Cleanup / Redundant Code |
| **5** | Remove assumed 10-tab quantity selector from Chemist Counter buy page (handle syrups, drops, liquids) | 🟢 **Completed** | UX / Domain Logic |
| **6** | Fix bottom pixel overflow when tapping search bar under "Enter Prescribed Medicine" | ⚪ Pending User Gate | Bug / Keyboard Avoidance |
| **7** | Remove duplicate "Scan Slip" button on Chemist Counter (currently in top-right AppBar and above search bar) | ⚪ Pending User Gate | UI / Redundant Action |
| **8** | Fix excessive empty whitespace in bottom sheet modal on Scan Slip (dynamically wrap content to ~50% height) | ⚪ Pending User Gate | UI / BottomSheet UX |
| **9** | Add anti-clockwise 90° rotation and style both rotate buttons in Deep Teal on free perspective crop screen | ⚪ Pending User Gate | Feature / Crop UX |
| **10** | Enhanced prescription intake parsing (number of days, dosage frequency `1-0-1`, `1-1-1`, `0-0-1`, timing before/after meals) | ⚪ Pending User Gate | Domain Logic / NLP Parser |
| **11** | Feasibility analysis & architecture report for Google AI / Gemini Vision API hybrid OCR fallback | ⚪ Pending User Gate | Architectural Report / AI Integration |
| **12** | Audit and improve medicine blister strip packaging OCR & expiry matching against cabinet inventory | ⚪ Pending User Gate | ML Kit OCR / Packaging Scanner |
| **13** | Audit and fix remaining screen pixel overflows across all tabs & views with comprehensive audit tally | ⚪ Pending User Gate | Responsive Polish / Screen Audit |

---

## 🛠️ Detailed Remediation Records

### Issue 1: Remove "Estimated Pharmacy Savings" UI
* **Status:** 🟢 **Completed & Deployed**
* **Root Cause:** A prominent green banner ticker (*"ESTIMATED PHARMACY SAVINGS: ₹XX.XX"*) was placed at the top of the Chemist Counter screen (`chemist_counter_screen.dart`), and each recommendation card appended a `(Save ₹XX.XX)` suffix. Because actual pharmacy discounts and generic drug prices vary arbitrarily across Indian retailers, estimating rupee savings was unrealistic, cluttered the interface, and distracted from the core safety objective: preventing duplicate medicine purchases and strength overdoses.
* **Changes Made:**
  1. Removed the entire top `Container` ticker widget containing the savings icon, title, and rupee formatting from [`ChemistCounterScreen`](../lib/features/chemist_counter/presentation/screens/chemist_counter_screen.dart).
  2. Removed `ref.watch(totalEstimatedSavingsProvider)` and its unused import (`formatters.dart`).
  3. Cleaned recommendation card text to focus solely on clinical actionable advice: `"💡 Recommendation: Buy only X tablets."`
  4. Removed dead `totalEstimatedSavingsProvider` from [`chemist_counter_controller.dart`](../lib/features/chemist_counter/presentation/controllers/chemist_counter_controller.dart).
* **Redundant Code Removed:**
  - Removed 44 lines of dead widget tree from `chemist_counter_screen.dart`.
  - Removed unused `totalEstimatedSavingsProvider` provider declaration from `chemist_counter_controller.dart`.
  - Removed unused `Formatters` import from `chemist_counter_screen.dart`.
* **Resolution & Testing Status:**
  - `flutter analyze`: **0 warnings / 0 errors**.
  - `flutter test`: **All 40 unit and widget tests pass**.
  - **Deployed to device:** Compiled and installed to connected phone (`CPH2613`). The Chemist Counter page now immediately presents the clean search and prescription scanner without any savings banners. Fully resolved.

---

### Issue 2: Overall UI Visual Overhaul & Polish
* **Status:** 🟢 **Completed & Deployed**
* **Root Cause:** The interface previously used default Material 3 component stylings (raw unstyled AppBars, flat rectangular card containers with thin 1px gray borders, raw `ChoiceChips`, basic system typography, and unstyled bottom navigation). This made the app feel like a generic student project or template rather than a modern, polished, and trustworthy clinical healthcare product (like Apple Health, One Medical, or PillPack).
* **Changes Made:**
  1. **Design System & Global Theme Tokens ([`app_colors.dart`](../lib/core/constants/app_colors.dart) & [`app_theme.dart`](../lib/core/theme/app_theme.dart)):**
     - Introduced `primaryGradient` (Teal `#0D9488` $\rightarrow$ `#0F766E`), `primarySurfaceBorder`, and layered ambient card drop-shadows (`cardShadow`, `subtleShadow`, `heroShadow`).
     - Standardized rounded corners to $20\text{px}$ for cards, $14\text{px}$ for buttons and inputs.
     - Upgraded typography hierarchy with intentional negative letter spacing (`-0.4` to `-0.2`) on headlines, crisp weights (`FontWeight.w800` for titles, `w700` for headers, `w500` for subtitles).
  2. **Navigation Shell ([`app.dart`](../lib/app.dart)):**
     - Enclosed bottom navigation bar in a sleek white container with top border and soft ambient upward shadow (`Color(0x0A0F172A)`, blur $16$).
     - Upgraded tab icons to medical inventory, pharmacy storefront, OCR document scanner, and alarm clock.
  3. **Cabinet Screen & Header ([`cabinet_screen.dart`](../lib/features/cabinet/presentation/screens/cabinet_screen.dart)):**
     - Added branded top App Bar with a gradient brand avatar, bold app title, and live `● 100% Offline Safe` emerald status pill.
     - Styled the 2:00 AM Quick Finder as an eye-catching amber pill action with lightning icon (`⚡ 2AM Quick`).
     - Replaced 3 disconnected gray stat boxes with an integrated **Micro-Dashboard** card featuring 3 metric columns (Total Items, Low Stock Alert, Expired/Alert) with custom background icon badges.
     - Upgraded category chips from standard `ChoiceChips` to custom animated pill buttons with active teal glow shadows.
  4. **Medicine Cards ([`medicine_card.dart`](../lib/features/cabinet/presentation/widgets/medicine_card.dart)):**
     - Replaced standard flat card with an elevated rounded container ($20\text{px}$) featuring soft ambient drop shadows.
     - Form-specific gradient avatar badges (Tablets, Capsules, Syrups, Drops, Inhalers) with color-coded safety indicators.
     - Sleek stock pill indicator (`X left` with low-stock warning tag).
     - Refined dual expiry badge with dot indicator and physical drawer location pill.
  5. **Chemist Counter & Adherence ([`chemist_counter_screen.dart`](../lib/features/chemist_counter/presentation/screens/chemist_counter_screen.dart) & [`adherence_screen.dart`](../lib/features/notifications/presentation/screens/adherence_screen.dart)):**
     - Upgraded prescription search bar with soft rounded styling and prominent Scan Slip pill trigger.
     - Redesigned active salt equivalence callout cards with soft emerald surfaces, checkmark icons, and clean recommendation pills.
     - Styled adherence cards with clock containers, meal relation tags, and pill-shaped "Taken" action buttons.
  6. **Scanner Prompt ([`ocr_scanner_screen.dart`](../lib/features/ocr_ingestion/presentation/screens/ocr_scanner_screen.dart)):**
     - Redesigned welcome view with circular gradient scanner icon, trust pills (`100% Offline`, `Fuzzy Dice Match`, `Zero Cloud Leak`), and elevated camera/gallery buttons.
* **Redundant Code Removed:**
  - Removed outdated standalone `_buildStatChip` implementation in `cabinet_screen.dart`.
  - Replaced legacy flat `Card` wrappers in `medicine_card.dart`, `chemist_counter_screen.dart`, and `adherence_screen.dart` with unified modern container decorations.
* **Resolution & Testing Status:**
  - `flutter analyze`: **0 warnings / 0 errors**.
  - `flutter test`: **All 40 unit and widget tests pass**.
  - **Deployed to device:** Compiled debug APK and streamed install to connected device (`CPH2613`). Verified brand header, navigation bar, micro-dashboard, and card elevations. Fully resolved.

---

### Issue 3: Fix Pixel Overflow on 2:00 AM Quick Finder Dialog
* **Status:** 🟢 **Completed & Deployed**
* **Root Cause:**
  1. **Keyboard Inset Overflow (Bottom RenderFlex):** The dialog used `TextField(autofocus: true)` inside an unconstrained `Dialog` containing a `Column(mainAxisSize: MainAxisSize.min)` with `Flexible(child: ListView.builder(shrinkWrap: true))`. When the soft keyboard popped up automatically upon dialog open, the keyboard took up $300-350\text{dp}$ of vertical space, squeezing the dialog below its required minimum content height and triggering a RenderFlex bottom overflow.
  2. **Horizontal Header Overflow (Right RenderFlex):** The dialog header had a `Row` containing an icon container and a raw `Column` with `"2:00 AM Quick Finder"` and `"Find medicines by immediate symptom"`. Because the `Column` was not wrapped in `Expanded`, devices with smaller screen widths or enlarged accessibility font scales overflowed on the right edge.
  3. **Lack of Dismiss Control:** The dialog had no explicit close button, forcing users to tap outside or hit system back.
* **Changes Made:**
  1. In [`EmergencySearchDialog`](../lib/features/cabinet/presentation/widgets/emergency_search_dialog.dart):
     - Added `insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24)`.
     - Wrapped dialog content in `ConstrainedBox` bounding maximum height to $75\%$ of screen height (`MediaQuery.of(context).size.height * 0.75`) and maximum width to $480\text{dp}$.
     - Wrapped header title `Column` in `Expanded` with `TextOverflow.ellipsis` to prevent any horizontal line break or right-side RenderFlex overflow.
     - Added an explicit `IconButton` close button (`Icons.close_rounded`) in the header for fast one-tap dismissal.
     - Changed `autofocus: false` on `TextField` so the keyboard doesn't aggressively jump on open, allowing the user to immediately see and tap the 6 quick symptom tags ('Acidity', 'Fever', 'Headache', etc.).
     - Converted the results list to `Expanded(child: ListView.separated(...))` so it smoothly resizes and scrolls within the remaining dialog bounds when the keyboard is summoned.
     - Added an empty state vector graphic container when no symptoms match cabinet stock.
  2. Added a comprehensive widget test suite in [`test/emergency_search_dialog_test.dart`](../test/emergency_search_dialog_test.dart) testing compact screen sizes ($360\times640$), quick symptom chip filtering, selection callbacks, and dialog dismissal.
* **Redundant Code Removed:**
  - Removed unstable `Flexible` + `shrinkWrap: true` nested inside `Column(mainAxisSize: MainAxisSize.min)`.
  - Removed outdated unstyled action chip shapes.
* **Resolution & Testing Status:**
  - `flutter analyze`: **0 warnings / 0 errors**.
  - `flutter test`: **All 42 unit and widget tests pass**.
  - **Deployed to device:** Compiled debug APK and streamed installation to connected phone (`CPH2613`). Verified dialog opens smoothly on mobile without keyboard clipping or pixel overflow. Fully resolved.

---

### Issue 4: Remove "Demo Data" Button & Static Seed Stash
* **Status:** 🟢 **Completed & Deployed**
* **Root Cause:** In earlier development iterations, a "Demo Data" button and a dedicated seeder class (`DemoDataSeeder`) were introduced to populate 5 hardcoded mock medicines (Crocin 650, Pantocid 40, Refresh Tears, Augmentin 625 Duo, and Ecosprin 75) into the SQLite cabinet database. Now that manual input, FTS5 catalog search, and packaging OCR pipelines are fully implemented and operational, the demo button is obsolete, creates developer-mode clutter in the AppBar and empty state, and could accidentally overwrite or inject duplicate mock items into real household inventories.
* **Changes Made:**
  1. Removed the "Demo" action button from `AppBar.actions` in [`CabinetScreen`](../lib/features/cabinet/presentation/screens/cabinet_screen.dart).
  2. In the empty state view of `CabinetScreen`, replaced the "Preload Sample Demo Stash" button with an "Add Your First Medicine" action button that navigates directly to [`AddMedicineScreen`](../lib/features/cabinet/presentation/screens/add_medicine_screen.dart).
  3. Deleted the `_seedDemoData()` method and removed the unused `CabinetRepository` import from `cabinet_screen.dart`.
  4. Completely deleted the static seed file [`lib/core/utils/demo_data_seeder.dart`](../lib/core/utils/demo_data_seeder.dart) and its 5 hardcoded mock medicine structures and mock schedules.
* **Redundant Code Removed:**
  - Deleted entire `lib/core/utils/demo_data_seeder.dart` (118 lines of static mock data and hardcoded seed routines).
  - Removed 54 lines of demo button UI, callback methods, and unused repository imports from `cabinet_screen.dart`.
* **Resolution & Testing Status:**
  - `flutter analyze`: **0 warnings / 0 errors**.
  - `flutter test`: **All 42 unit and widget tests pass**.
  - **Deployed to device:** Compiled debug APK and streamed installation to connected phone (`CPH2613`). The AppBar and empty cabinet state are now completely free of demo buttons. Fully resolved.

---

### Issue 5: Remove Assumed 10-Tab Quantity Selector & Introduce Form-Aware Units
* **Status:** 🟢 **Completed & Deployed**
* **Root Cause:** The Chemist Counter search header placed a global `[5, 10, 15, 20, 30] tabs` dropdown right next to the search bar. This had two major flaws:
  1. It falsely assumed every medicine is an oral tablet/capsule sold in strips of 10. When purchasing liquid cough syrups, eye drops, ointments, or sprays, defaulting to "10 tabs" is domain-illogical (users do not buy "10 bottles" or "10 tabs of eye drops").
  2. The dropdown occupied significant horizontal width, compressing the search input field and causing horizontal text clipping and keyboard insets layout pressure.
* **Changes Made:**
  1. **Removed Global Dropdown Selector:** Completely removed the `DropdownButton<int>` from the search bar row in [`ChemistCounterScreen`](../lib/features/chemist_counter/presentation/screens/chemist_counter_screen.dart). The search bar now spans the full width of the container.
  2. **Form-Aware Initial Quantity Logic:** In `_addPrescribedMedicine()`, dynamically inspect `record.dosageForm`:
     - Liquids, syrups, suspensions, drops, ointments, gels, sprays, and inhalers default to `quantityPrescribed = 1` unit (1 bottle/tube).
     - Oral solid dosage forms (tablets, capsules) default to `quantityPrescribed = 10` (1 standard strip).
  3. **Cart Item Stepper:** Added an interactive `+ / -` stepper on each cart card. Tapping `+` or `-` updates the specific item quantity with form-aware step sizes (1 for bottles/tubes, 5 for tablets).
  4. **Domain-Accurate Unit Formatting ([`chemist_cart_item.dart`](../lib/features/chemist_counter/data/models/chemist_cart_item.dart) & [`smart_buy_result.dart`](../lib/features/chemist_counter/data/models/smart_buy_result.dart)):**
     - Added `isLiquidOrUnitItem` and `unitLabel` getters.
     - Recommendation cards now dynamically display proper units:
       - Tablets: `"You already have 8 tablets ... Buy only 2 tablets."`
       - Syrups/Liquids: `"You already have 1 bottle ... Buy only 1 bottle."`
       - Ointments/Gels: `"You already have 1 tube ... Buy only 1 tube."`
  5. Added automated unit tests in [`test/domain_services_test.dart`](../test/domain_services_test.dart) verifying unit label formatting and equivalence evaluation for liquid syrups.
* **Redundant Code Removed:**
  - Removed `_prescribedQuantity` global dropdown state from `_ChemistCounterScreenState`.
  - Removed hardcoded `"tabs"` string concatenations across evaluation callouts.
* **Resolution & Testing Status:**
  - `flutter analyze`: **0 warnings / 0 errors**.
  - `flutter test`: **All 43 unit and widget tests pass**.
  - **Deployed to device:** Compiled debug APK and streamed installation to connected phone (`CPH2613`). Verified that searching a syrup automatically adds 1 bottle with a responsive stepper, and search input spans full width. Fully resolved.

---

*(Additional remediation records will be appended sequentially upon each issue completion)*
