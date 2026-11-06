# MedWise — Comprehensive Issue Tracking & Remediation Log

> **Context:** Post-Testing Feedback & App Polish Sprint  
> **Status:** Active Execution (One-by-One Remediation with User Gatekeeper)  
> **Rule:** Resolve issues strictly one-by-one. Report root cause, code changes, redundant code removal, and verification status. Await user confirmation ("yes") before proceeding to the next issue.

---

## 📋 Master Issue Tracker

| # | Issue Summary | Status | Category |
|---|---|---|---|
| **1** | Remove "Estimated Pharmacy Savings" ticker and related UI | 🟢 **Completed** | UI Simplification / Feature Removal |
| **2** | Overall UI visual overhaul & polish (elevate from generic to premium healthcare aesthetic) | ⚪ Pending User Gate | UI / Design System |
| **3** | Fix pixel overflow on 2:00 AM Quick Finder dialog | ⚪ Pending User Gate | Bug / Responsive UI |
| **4** | Remove "Demo Data" button and static seed stash | ⚪ Pending User Gate | Cleanup / Redundant Code |
| **5** | Remove assumed 10-tab quantity selector from Chemist Counter buy page (handle syrups, drops, liquids) | ⚪ Pending User Gate | UX / Domain Logic |
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

*(Additional remediation records will be appended sequentially upon each issue completion)*
