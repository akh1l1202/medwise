# MedWise — Master Implementation Roadmap & Progress Tracker

> **Project:** MedWise (Offline-First Medicine Cabinet & Smart Chemist-Counter Companion)  
> **Status:** Phase 0 (Foundation & Scaffolding) completed. Moving to Phase 1 (Home Cabinet Experience).  
> **Last Updated:** October 2026

---

## 📊 High-Level Phase Overview

| Phase | Module / Milestone | Status | Key Deliverables |
| :--- | :--- | :--- | :--- |
| **Phase 0** | **Architecture Scaffolding & Data Pipeline** | 🟢 **Completed** | Clean architecture folders, Riverpod notifiers, bundled SQLite with FTS5, curated interactions JSON, domain services, tests. |
| **Phase 1** | **Home Cabinet Experience & Inventory CRUD** | 🟢 **Completed** | Full interactive cabinet dashboard, urgency banners, pill counters, 2:00 AM symptom search, manual FTS5 add/edit screens. |
| **Phase 2** | **Blister Strip & Box Camera OCR Pipeline** | 🟢 **Completed** | Camera/gallery picker, ML Kit text extraction, Dice's coefficient fuzzy matching, Human-in-the-Loop review screen with confidence badges. |
| **Phase 3** | **Chemist Counter "Smart Buy" Mode** | 🟢 **Completed** | FTS5 prescription cart, Active Salt Equivalence engine, Strength Guard alerts, ₹ savings calculator, checklist, 1-tap sync. |
| **Phase 4** | **Curated Drug Interactions & Clinical Safety** | 🟢 **Completed** | Pairwise safety engine watching cabinet, critical/moderate hazard alert cards, multi-drug combinations. |
| **Phase 5** | **Exact Dose Alarms, Auto-Depletion & Adherence** | 🟢 **Completed** | Dose schedules, auto-decrement on "Mark Taken", 28-day open sterility clock, antibiotic adherence tracker ("Day X of Y"). |
| **Phase 6** | **Family Profiles, Biometric Lock & Export** | ⚪ Pending | Multi-user profiles, allergy safeguards, biometric authentication (`local_auth`), 1-click doctor PDF summary. |
| **Phase 7** | **Viva Demo Script, Sample Stash & Final Polish** | 🟡 **In Progress** | 1-click viva sample data seeder (implemented), 3-minute evaluation rehearsals, offline airplane-mode hardening. |

---

## 📝 Detailed Phase-by-Phase Task Breakdown

### 🟢 Phase 0: Project Scaffolding & Foundation Setup (Completed)
- [x] **Project Scaffolding:** Initialized Flutter 3.x project with Material 3, Riverpod 2.x, and Clean Architecture (`core/`, `features/`, `data/`, `domain/`, `presentation/`).
- [x] **Design Tokens & Theme:** Created [`AppColors`](../lib/core/constants/app_colors.dart) (Deep Emerald Teal `#0F766E`, Semantics `#10B981` / `#F59E0B` / `#EF4444`, Slate hierarchy) and [`AppTheme`](../lib/core/theme/app_theme.dart).
- [x] **Indian Pharmacopoeia Database:**
  - [x] Built SQLite database [`assets/database/indian_medicines.db`](../assets/database/indian_medicines.db) populated with 83+ high-frequency Indian formulations.
  - [x] Enabled Full-Text Search virtual table (`medicines_fts`) using SQLite FTS5 for sub-millisecond autocomplete.
  - [x] Created [`BundledDbHelper`](../lib/core/database/bundled_db_helper.dart) with auto-copy from assets to local app storage.
- [x] **User Cabinet Database:**
  - [x] Built SQLite database helper [`CabinetDbHelper`](../lib/core/database/cabinet_db_helper.dart) managing `cabinet_items`, `intake_schedules`, and `family_profiles`.
  - [x] Enforced foreign keys and preloaded default primary profile ("Self").
- [x] **Curated Drug-Drug Interactions:**
  - [x] Compiled offline clinical dataset [`assets/data/drug_interactions.json`](../assets/data/drug_interactions.json) covering 50+ critical/moderate drug pairs.
- [x] **Core Models & Repositories:**
  - [x] [`MedicineRecord`](../lib/features/medicine_catalog/data/models/medicine_record.dart) & [`MedicineCatalogRepository`](../lib/features/medicine_catalog/data/repositories/medicine_catalog_repository.dart).
  - [x] [`CabinetItem`](../lib/features/cabinet/data/models/cabinet_item.dart) & [`CabinetRepository`](../lib/features/cabinet/data/repositories/cabinet_repository.dart).
  - [x] [`IntakeSchedule`](../lib/features/cabinet/data/models/intake_schedule.dart).
  - [x] [`FamilyProfile`](../lib/features/profiles/data/models/family_profile.dart) & [`ProfileRepository`](../lib/features/profiles/data/repositories/profile_repository.dart).
  - [x] [`DrugInteractionRule`](../lib/features/drug_interactions/data/models/drug_interaction_rule.dart) & [`DrugInteractionRepository`](../lib/features/drug_interactions/data/repositories/drug_interaction_repository.dart).
  - [x] [`ChemistCartItem`](../lib/features/chemist_counter/data/models/chemist_cart_item.dart) & [`SmartBuyResult`](../lib/features/chemist_counter/data/models/smart_buy_result.dart).
  - [x] [`MatchCandidate`](../lib/features/ocr_ingestion/data/models/match_candidate.dart) & [`OcrScanResult`](../lib/features/ocr_ingestion/data/models/ocr_scan_result.dart).
- [x] **Core Domain Engines:**
  - [x] [`SaltEquivalenceService`](../lib/features/chemist_counter/domain/services/salt_equivalence_service.dart) (Salt mapping, Strength Guard, ₹ savings).
  - [x] [`InteractionCheckerService`](../lib/features/drug_interactions/domain/services/interaction_checker_service.dart) (Pairwise clinical cross-referencing).
  - [x] [`FuzzyMatcherService`](../lib/features/ocr_ingestion/domain/services/fuzzy_matcher_service.dart) (Dice's Coefficient bigram similarity).
  - [x] [`ExpiryCalculatorService`](../lib/features/cabinet/domain/services/expiry_calculator_service.dart) (Dual printed & 28-day open sterility rules).
  - [x] [`DoseDepletionService`](../lib/features/cabinet/domain/services/dose_depletion_service.dart) (Auto-stock decrement & low-stock check).
  - [x] [`NotificationAlarmService`](../lib/features/notifications/services/notification_alarm_service.dart) (Native Android 12+ alarms setup).
- [x] **Quality Assurance & Verification:**
  - [x] Passing 7/7 unit & widget tests in [`test/domain_services_test.dart`](../test/domain_services_test.dart) and [`test/widget_test.dart`](../test/widget_test.dart).
  - [x] Zero static analysis issues (`flutter analyze` clean).

---

### 🟢 Phase 1: Home Cabinet Experience & Inventory CRUD (Completed)
- [x] **1.1 Cabinet Dashboard Screen (`CabinetOverviewScreen`)**:
  - [x] Header banner with active user profile, quick search button, and total stock summary.
  - [x] Urgency Alerts Banner:
    - [x] Expired medicines alert.
    - [x] Expiring within 30 days alert.
    - [x] Open sterility limit breached for syrups/eye drops (28-day rule warning).
    - [x] Low stock alert ($\le 2$ tablets remaining).
  - [x] Inventory Filter Tabs: "All", "Tablets", "Syrups & Drops", "Low Stock".
  - [x] Medicine Card Widget:
    - [x] Dosage form icons (tablet, liquid, dropper, inhaler).
    - [x] Brand name and active salt subtitle.
    - [x] Quantity pill badge (colored green/neutral, red if low $\le 2$).
    - [x] Expiry chip with dual status (printed date + remaining sterility days).
    - [x] Storage location tag (*"Living Room Drawer"*, *"Fridge Door"*).
    - [x] Swipe-to-delete with dismissal animation.
- [x] **1.2 Medicine Item Detail & Action Modal**:
  - [x] Full pharmacological details (Brand, Salt, Strength, Form).
  - [x] Direct quantity stepper (`+` / `-` buttons to manually adjust count).
  - [x] *"Mark Opened Today"* action button (starts 28-day countdown clock for liquids/drops).
  - [x] Storage location and symptom tags display.
- [x] **1.3 Manual Medicine Addition Screen & FTS5 Autocomplete**:
  - [x] High-speed search bar connected to `medicines_fts` with instant suggestions as the user types 2 characters.
  - [x] Auto-population of Brand Name, Active Salt, Strength, and Form upon selecting a catalog item.
  - [x] Custom medicine entry support for uncataloged brands.
  - [x] Storage location selector with default quick-chips (*"Living Room Drawer"*, *"Kitchen Stash"*, *"Fridge Door"*, etc.).
- [x] **1.4 2:00 AM Emergency Symptom Finder**:
  - [x] Instant search trigger from top app bar.
  - [x] Search input for symptoms (*"Acidity"*, *"Fever"*, *"Headache"*, *"Cough"*, *"Dry Eyes"*).
  - [x] Returns active matching cabinet items with prominent bold storage location directions.

---

### 🟢 Phase 2: Blister Strip & Box Camera OCR Pipeline (Completed)
- [x] **2.1 Camera & Image Capture Flow**:
  - [x] Camera trigger via `image_picker` (Camera capture + Gallery picker fallback).
  - [x] Visual camera framing guide with aspect ratio tuned for blister packs and carton boxes.
- [x] **2.2 On-Device Extraction & Fuzzy Confidence Pipeline**:
  - [x] On-device text recognition with `google_mlkit_text_recognition`.
  - [x] Regex date extraction parsing printed expiration stamps (`EXP. 08/2026`, `EXP: 08/26`, `11/2025`).
  - [x] Dice's Coefficient bigram similarity calculation matching extracted lines against pre-bundled SQLite catalog.
  - [x] Categorize matches into Confidence Tiers:
    - [x] 🟢 **High Match ($\ge 90\%$)**: Direct match badge.
    - [x] 🟠 **Medium Match ($70\% - 89\%$)**: Suggested match badge.
    - [x] 🔴 **Low Match ($< 70\%$)**: Manual input required.
- [x] **2.3 Human-in-the-Loop OCR Review & Confirmation Screen**:
  - [x] Photo thumbnail preview highlighting detected text blocks.
  - [x] Confidence Badge pill displayed prominently.
  - [x] "Did you mean?" suggestions dropdown if similarity is medium.
  - [x] Editable verification form (Brand Name, Active Salt, Strength, Expiry Date, Form).
  - [x] Location and Profile assignment before final save.
  - [x] 1-Tap *"Confirm & Save to Cabinet"*.
- [x] **2.4 Computerized Doctor Prescription Slip Scanner (Chemist Batch Ingestion)**:
  - [x] Extract printed text blocks from computerized clinic/hospital prescriptions (Apollo, Practo, Max, OPD slips).
  - [x] On-device filtering of clinic headers, vitals (BP, Pulse, Temp), and doctor metadata.
  - [x] Regex dosage parser (`1-0-1 x 5 days` $\rightarrow$ 10 tablets, `BD x 5 days` $\rightarrow$ 10 tablets, explicit quantities `10 tabs`).
  - [x] Match candidate lines against Indian Pharmacopoeia SQLite catalog with Dice's coefficient confidence scoring.
  - [x] Verification bottom sheet modal (`PrescriptionScanModal`) with quantity steppers and confidence badges.
  - [x] Direct batch import into Chemist Counter cart for immediate active salt equivalence and ₹ savings calculation.
  - [x] Dedicated unit tests in [`test/prescription_scanner_test.dart`](../test/prescription_scanner_test.dart) (all 4 passing).

---

### 🟢 Phase 3: Chemist Counter "Smart Buy" Mode (Completed)
- [x] **3.1 Prescribed Medicine Entry Screen**:
  - [x] Fast FTS5 autocomplete search bar to add medicines from a paper prescription.
  - [x] Prescribed quantity dropdown (5, 10, 15, 20, 30 tablets).
  - [x] Prescription cart list displaying pending items.
- [x] **3.2 Active Salt Equivalence Engine UI**:
  - [x] Real-time equivalence card:
    - [x] Prescribed: *Dolo 650* (10 tabs) $\longleftrightarrow$ Home Stock: *Crocin 650* (8 tabs owned).
    - [x] Active salt callout: *Paracetamol 650mg*.
    - [x] Storage location reminder: *"Stored in Living Room Drawer"*.
- [x] **3.3 Strength Guard Warning Card**:
  - [x] Explicit caution alert when active salt matches but concentration differs (e.g., prescribed 650mg vs owned 500mg).
  - [x] Warning: *"Same active ingredient, but different strength. Consult chemist before substituting."*
- [x] **3.4 Smart Purchase Recommendation & ₹ Savings Widget**:
  - [x] "Buy Only X Tablets" calculation (e.g., Prescribed 10, Own 8 $\rightarrow$ Buy 2).
  - [x] Real-time savings ticker: *"Estimated Pharmacy Savings: ₹X.XX"*.
  - [x] Interactive checklist for checking off medicines as the pharmacist hands them over.
  - [x] *"Add Purchased to Cabinet"* button to instantly update home inventory with newly bought items.

---

### 🟢 Phase 4: Curated Drug Interactions & Clinical Safety (Completed)
- [x] **4.1 Real-Time Interaction Cross-Referencing**:
  - [x] Automatic check whenever a medicine is added to the Chemist Cart or Cabinet.
  - [x] Pairwise evaluation against all currently active cabinet items.
- [x] **4.2 Interaction Alert Modal & Severity Indicators**:
  - [x] 🔴 **Critical Hazard Alert**:
    - [x] E.g., *Aspirin + Warfarin* (Hemorrhage risk), *Metformin + Alcohol* (Lactic acidosis).
    - [x] Clear clinical explanation of adverse effect.
    - [x] Explicit guidance: *"Avoid concurrent use unless directed by doctor."*
  - [x] 🟠 **Moderate Warning Alert**:
    - [x] E.g., *Ibuprofen + Paracetamol* (Renal strain, dose staggering advisory).
  - [x] ⚠️ **Duplicate Paracetamol Alert**:
    - [x] Warns when combining multi-ingredient remedies that both contain Paracetamol to prevent hepatotoxicity.

---

### 🟢 Phase 5: Exact Dose Alarms, Auto-Depletion & Adherence (Completed)
- [x] **5.1 Dose Schedule Configuration Screen**:
  - [x] Select medicine from Cabinet.
  - [x] Pick dose time(s) (e.g. 08:00 AM, 08:30 PM).
  - [x] Meal relation selector (*Before Food*, *After Food*, *With Food*).
  - [x] Set dose amount (e.g. 1.0 tablet).
  - [x] Antibiotic course toggle (Total days, e.g. 5 days).
- [x] **5.2 Native Exact Alarms with Action Buttons**:
  - [x] Daily alarms scheduled via `flutter_local_notifications` + `timezone`.
- [x] **5.3 Automatic Cabinet Stock Depletion**:
  - [x] Tapping *"Mark Taken"* decrements remaining cabinet pills by `doseAmount`.
  - [x] Proactive refill notification when stock drops below 2-day supply.
- [x] **5.4 Antibiotic Adherence Tracker ("Day X of Y")**:
  - [x] Prominent banner on Adherence screen (*"Antibiotic Regimen: Day 3 of 5"*).
  - [x] Educational warning against stopping early to combat antibiotic resistance.
  - [x] Automatic day increment when daily doses are marked taken.
- [x] **5.5 28-Day "Opened-On" Sterility Clock Engine**:
  - [x] Visual countdown gauge for liquid syrups and eye drops.
  - [x] Expiry badge indicators and sterility breached warnings.

---

### ⚪ Phase 6: Multi-User Family Profiles, Biometric Security & PDF Export
- [ ] **6.1 Multi-User Family Profiles**:
  - [ ] Profile switcher in app bar (Self, Parents, Children, Spouse).
  - [ ] Filter cabinet inventory and dose reminders by family member.
  - [ ] Allergy Safeguard:
    - [ ] Store documented drug allergies per profile (e.g. *Penicillin*, *Sulfa*).
    - [ ] Alert when adding medicines containing allergic salts to that profile.
- [ ] **6.2 Biometric Privacy Lock (`local_auth`)**:
  - [ ] Biometric prompt (Fingerprint / Face ID / PIN) on cold launch and app resume.
  - [ ] Settings toggle to enable/disable biometric security.
- [ ] **6.3 Cabinet Purge & Safe Disposal Guide**:
  - [ ] Filter screen displaying all expired or sterility-breached medications.
  - [ ] Environmental safety guidelines (preventing antibiotic dumping in waterways).
  - [ ] 1-Tap *"Purge All Expired"* action.
- [ ] **6.4 1-Click Doctor Visit PDF Summary (Stretch Goal)**:
  - [ ] Compile active medications, doses, schedules, and allergies into a clean PDF.
  - [ ] Share or print via `printing` package.

---

### ⚪ Phase 7: Evaluator Demo Hardening & Viva Rehearsal
- [ ] **7.1 1-Click Sample Demo Stash Seeder**:
  - [ ] Button in developer/settings menu to seed a realistic household medicine drawer:
    - *Crocin 650 (8 tablets, Exp: 12/2027)*
    - *Pantocid 40 (14 tablets, Exp: 06/2027)*
    - *Refresh Tears Eye Drops (Opened 12 days ago, 16 days left)*
    - *Augmentin 625 Duo (Day 3 of 5 antibiotic course)*
    - *Warfarin 2mg (Active anticoagulant)*
- [ ] **7.2 Evaluator 3-Minute Viva Voce Demo Drill**:
  - [ ] Rehearse Step 1: Dilemma & Biometric Unlock.
  - [ ] Rehearse Step 2: Chemist Counter "Smart Buy" (*Dolo 650 prescribed $\rightarrow$ Crocin 650 detected, Buy 2, Save ₹*).
  - [ ] Rehearse Step 3: Strip OCR with 94% Green Confidence Badge.
  - [ ] Rehearse Step 4: 28-Day Eye Drop Clock, Drug Interaction (Aspirin + Warfarin), and Auto-Depletion on "Mark Taken".
- [ ] **7.3 100% Offline Airplane Mode Verification**:
  - [ ] Verify zero network calls during entire demo flow.

---

## 📅 Suggested Execution Sprints

```
Sprint 1 (Now)      ──► Phase 1: Home Cabinet Dashboard, FTS5 Search & CRUD
Sprint 2            ──► Phase 2: Blister Strip & Box Camera OCR Pipeline
Sprint 3            ──► Phase 3 & 4: Chemist Counter "Smart Buy" & Interactions
Sprint 4            ──► Phase 5 & 6: Alarms, Auto-Depletion, Profiles & Biometrics
Final Polish (Viva) ──► Phase 7: Demo Seeder & Evaluator Presentation Rehearsal
```
