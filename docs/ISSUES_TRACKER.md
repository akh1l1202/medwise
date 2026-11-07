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
| **6** | Fix bottom pixel overflow when tapping search bar under "Enter Prescribed Medicine" | 🟢 **Completed** | Bug / Keyboard Avoidance |
| **7** | Remove duplicate "Scan Slip" button on Chemist Counter (currently in top-right AppBar and above search bar) | 🟢 **Completed** | UI / Redundant Action |
| **8** | Fix excessive empty whitespace in bottom sheet modal on Scan Slip (dynamically wrap content to ~50% height) | 🟢 **Completed** | UI / BottomSheet UX |
| **9** | Add anti-clockwise 90° rotation and style both rotate buttons in Deep Teal on free perspective crop screen | 🟢 **Completed** | Feature / Crop UX |
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

### Issue 6: Fix Bottom Pixel Overflow When Tapping Search Bar Under "Enter Prescribed Medicine"
* **Status:** 🟢 **Completed & Deployed**
* **Root Cause:**
  1. **Unscrollable Empty Viewport:** In [`ChemistCounterScreen`](../lib/features/chemist_counter/presentation/screens/chemist_counter_screen.dart), when the prescription cart was empty, the view rendered an unscrollable `Center` widget with fixed vertical padding and fixed-height icons/texts totaling $\approx 246\text{px}$.
  2. **Rigid Autocomplete Card in Fixed Header:** When typing in the search bar, the matching medicines suggestions card was placed inside the non-scrollable header `Column` above the `Expanded` cart list, occupying an additional $\approx 240\text{px}$.
  3. **Soft Keyboard Inset Pressure:** When the user tapped into `TextField`, the Android soft keyboard occupied $300-350\text{dp}$ of vertical screen real estate. On standard compact devices ($640\text{dp}$ total height), the visible viewport shrank to only $\approx 250\text{dp}$. Forcing the $120\text{dp}$ search bar container plus either the rigid $246\text{dp}$ empty state or the fixed suggestions box into $250\text{dp}$ caused an immediate bottom `RenderFlex overflowed by XX pixels`.
  4. **Unexpanded Header Row:** The header title `Text('Enter Prescribed Medicine')` and the `Scan Slip` pill button sat in an unconstrained `Row(mainAxisAlignment: MainAxisAlignment.spaceBetween)`. On narrow viewports or under larger text accessibility scalings, this caused horizontal line pressure.
* **Changes Made:**
  1. **Scrollable Empty State Container:** Wrapped the empty cart column in `SingleChildScrollView(physics: const BouncingScrollPhysics(), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16))` so it fluidly shrinks or scrolls on compact viewports without clipping.
  2. **Relocated Suggestions to Expanded Region:** Moved the autocomplete suggestions list out of the rigid fixed header `Column` and placed it into the `Expanded` region of the body. When suggestions are active, they take full advantage of the remaining viewport with an internal `ListView.separated` and a top header with item count and a one-tap "Dismiss" button.
  3. **Header Flexibility & Keyboard Dismissal:**
     - Wrapped `'Enter Prescribed Medicine'` in `Expanded` with `TextOverflow.ellipsis`.
     - Wrapped the entire screen in `GestureDetector(onTap: () => FocusScope.of(context).unfocus(), behavior: HitTestBehavior.translucent)` so tapping anywhere outside dismisses the soft keyboard immediately.
     - Added an inline clear button (`Icons.clear_rounded`) to the `TextField` suffix icon when the search query is non-empty.
  4. **Conditional Bottom Action Button:** Added `final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;` and conditionally hid the bottom *"Add Purchased to Cabinet"* bar while the keyboard is active, preserving all remaining viewport for search results.
  5. **Automated Overflow Test Suite:** Created [`test/chemist_counter_overflow_test.dart`](../test/chemist_counter_overflow_test.dart) with a compact $360\times640$ viewport and simulated $350\text{dp}$ keyboard bottom insets, verifying zero RenderFlex overflows when focusing the search input.
* **Redundant Code Removed:**
  - Removed duplicate fixed `Card` container for suggestions that was cluttering the top header column.
  - Eliminated rigid non-scrollable layout constraints in the empty prescription cart state.
* **Resolution & Testing Status:**
  - `dart analyze`: **0 warnings / 0 errors**.
  - `flutter test`: **All 44 unit and widget tests pass (including new `chemist_counter_overflow_test.dart`)**.
  - **Deployed to device:** Compiled debug APK and streamed installation to physical phone (`CPH2613`). The app launches cleanly and tapping the search bar opens the keyboard smoothly with 0 pixel overflow warnings. Fully resolved.

---

### Issue 7: Remove Duplicate "Scan Slip" Button on Chemist Counter
* **Status:** 🟢 **Completed & Deployed**
* **Root Cause:** In [`ChemistCounterScreen`](../lib/features/chemist_counter/presentation/screens/chemist_counter_screen.dart), there were two identical action buttons invoking `_showPrescriptionScanModal()`:
  1. An unlabelled `IconButton(icon: Icon(Icons.document_scanner_outlined))` located in the top-right `AppBar.actions`.
  2. A dedicated contextual emerald pill button (`Icon + 'Scan Slip'`) located directly next to *"Enter Prescribed Medicine"* above the search input bar.
  Having both buttons created visual redundancy, cognitive clutter, and wasted AppBar action space.
* **Changes Made:**
  1. Removed the redundant `IconButton(icon: Icon(Icons.document_scanner_outlined))` from `AppBar.actions` in [`chemist_counter_screen.dart`](../lib/features/chemist_counter/presentation/screens/chemist_counter_screen.dart).
  2. Preserved the prominent, contextual, and labelled emerald pill button (`Scan Slip`) directly beside the prescription search input, where users make the immediate decision whether to type or scan.
  3. Added an automated widget test in [`test/chemist_counter_overflow_test.dart`](../test/chemist_counter_overflow_test.dart) verifying that exactly one "Scan Slip" trigger exists on the screen and no document scanner icon button resides in the AppBar.
* **Redundant Code Removed:**
  - Removed the duplicate `IconButton` action and its tooltip from `AppBar.actions`.
* **Resolution & Testing Status:**
  - `dart analyze`: **0 warnings / 0 errors**.
  - `flutter test`: **All 45 unit and widget tests pass**.
  - **Deployed to device:** Compiled debug APK and streamed installation to physical phone (`CPH2613`). Verified that the AppBar top-right is clean and only the contextual "Scan Slip" pill button is displayed above the search field. Fully resolved.

---

### Issue 8: Fix Excessive Empty Whitespace in Bottom Sheet Modal on "Scan Slip"
* **Status:** 🟢 **Completed & Deployed**
* **Root Cause:** In [`PrescriptionScanModal`](../lib/features/chemist_counter/presentation/widgets/prescription_scan_modal.dart), the root `Container` was constrained to `maxHeight: MediaQuery.of(context).size.height * 0.88`, and its child was a `Column` with default `mainAxisSize: MainAxisSize.max`.
  In the initial upload prompt state (`_imagePath == null`), the children inside the modal (drag handle, header, and Camera/Gallery picker card) only required $\approx 320\text{px}$ of vertical height. Because `Column` defaulted to `MainAxisSize.max`, the modal expanded to the full $88\%$ of the screen ($\approx 700\text{px}$ on standard devices), leaving $\approx 380\text{px}$ of completely blank, empty whitespace below the action buttons.
* **Changes Made:**
  1. **Dynamic Content Wrapping:** Split the modal body into a dual-mode layout:
     - When `_imagePath == null` (initial photo prompt state): Wrapped the content in `SingleChildScrollView(physics: const BouncingScrollPhysics(), child: Column(mainAxisSize: MainAxisSize.min, ...))`. This ensures the bottom sheet measures its children naturally and rolls up to **only the required height ($\approx 45-50\%$ of screen height)** with balanced top and bottom margins, completely eliminating the empty void.
     - When `_imagePath != null` (OCR results, verification, and editing): Seamlessly switches to `Column(crossAxisAlignment: CrossAxisAlignment.start, ...)` with `Expanded` scrollable candidate lists, utilizing up to $88\%$ of the viewport for reviewing detected medicines and adjusting quantities.
  2. **Refined Picker Card & Responsive Buttons:**
     - Restyled `_buildInitialUploadPrompt()` with a circular emerald scanner icon, balanced padding, and wrapped Camera & Gallery buttons in `Expanded` inside a responsive `Row` to eliminate horizontal line pressure on narrow devices.
  3. **Automated Verification Test:** Added a test in [`test/chemist_counter_overflow_test.dart`](../test/chemist_counter_overflow_test.dart) asserting that on an $800\text{px}$ tall screen, opening `PrescriptionScanModal` produces a snug modal height well below $500\text{px}$ (measuring $\approx 45-50\%$) with zero layout overflows.
* **Redundant Code Removed:**
  - Removed rigid fixed `Column(mainAxisSize: MainAxisSize.max)` in the initial scan prompt.
  - Eliminated oversized, disconnected margin blocks inside the picker container.
* **Resolution & Testing Status:**
  - `dart analyze`: **0 warnings / 0 errors**.
  - `flutter test`: **All 46 unit and widget tests pass**.
  - **Deployed to device:** Compiled debug APK and streamed installation to physical phone (`CPH2613`). Tapping "Scan Slip" now rolls up an elegant, compact modal taking up ~50% of the screen directly framing the Camera and Gallery actions with no dead space. Fully resolved.

---

### Issue 9: Add Anti-Clockwise 90° Rotation & Style Both Rotate Buttons in Deep Teal
* **Status:** 🟢 **Completed & Deployed**
* **Root Cause:** In [`PrescriptionCropScreen`](../lib/features/ocr_ingestion/presentation/screens/prescription_crop_screen.dart):
  1. The AppBar previously displayed only two action buttons: `Icons.rotate_right_rounded` (Rotate 90° clockwise) and `Icons.restart_alt_rounded` (Reset Corners). Because `Icons.restart_alt_rounded` renders as a counter-clockwise looped arrow ↺, users naturally expected it to rotate the prescription anti-clockwise by $90^\circ$. Instead, it was styled in muted gray (`AppColors.textSecondary`) and only reset the corner polygon anchors (`_resetCrop()`).
  2. There was no dedicated anti-clockwise rotation method (`_rotateCounterClockwise`) or button in the interface.
* **Changes Made:**
  1. **Anti-Clockwise Rotation Method:** Implemented `_rotateCounterClockwise()` in `_PrescriptionCropScreenState`, calculating `_rotationDegrees = (_rotationDegrees - 90 + 360) % 360` and invalidating `_quad` so the perspective crop box automatically re-centers on the newly rotated orientation.
  2. **Dual Teal Rotate Buttons:**
     - Added `IconButton(icon: Icon(Icons.rotate_left_rounded, size: 24, color: AppColors.primary), tooltip: 'Rotate 90° Anti-Clockwise', onPressed: _rotateCounterClockwise)`.
     - Preserved `IconButton(icon: Icon(Icons.rotate_right_rounded, size: 24, color: AppColors.primary), tooltip: 'Rotate 90° Clockwise', onPressed: _rotateClockwise)`.
     - Both rotate buttons are now prominently styled in brand Deep Teal (`AppColors.primary`).
  3. **Removed Redundant Third Rightmost Button:** Removed the third `Icons.restart_alt_rounded` icon from the AppBar actions, leaving exclusively the dual green rotation controls (↺ and ↻) in the top-right.
  4. **Overflow Protection:** Wrapped the AppBar title texts in `TextOverflow.ellipsis` and `maxLines: 1` to guarantee zero horizontal crowding or overflow on compact viewports.
  5. **Automated Unit & Widget Tests:**
     - Added unit test in [`test/image_cropper_test.dart`](../test/image_cropper_test.dart) verifying $270^\circ$ (anti-clockwise $90^\circ$) bitmap transformation and dimension swapping.
     - Created [`test/prescription_crop_screen_test.dart`](../test/prescription_crop_screen_test.dart) testing both rotate buttons exist, are colored `AppColors.primary`, and that no extra third button exists.
* **Redundant Code Removed:**
  - Removed the unreferenced `_resetCrop()` declaration and the third `Icons.restart_alt_rounded` button from `prescription_crop_screen.dart`.
* **Resolution & Testing Status:**
  - `dart analyze`: **0 warnings / 0 errors**.
  - `flutter test`: **All 48 unit and widget tests pass**.
  - **Deployed to device:** Compiled debug APK and streamed installation to physical phone (`CPH2613`). The top-right now displays only the two green rotation controls (↺ Anti-Clockwise and ↻ Clockwise) with zero third icon clutter. Fully resolved.

---

*(Additional remediation records will be appended sequentially upon each issue completion)*
