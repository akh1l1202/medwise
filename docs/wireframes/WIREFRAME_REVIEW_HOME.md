# Home Dashboard Wireframe — Review & Enhancement Specification

* **Master Wireframe:** [`docs/wireframes/home_dashboard_master.png`](./home_dashboard_master.png)
* **Alternative Variant:** [`docs/wireframes/home_dashboard_variant.png`](./home_dashboard_variant.png)
* **Design Standard Selected:** Variant 2 (Screen `676bbf2f...`)

---

## 1. Why Variant 2 Was Selected as the Master

1. **Clear Hero Visual Hierarchy:** The filled dark-teal button for **`[📷 Scan Strip / Box]`** immediately signals the app's primary input action.
2. **Accessible Tap Targets:** The full-width pill button **`[✓ Mark Taken]`** provides an effortless touch target compared to cramped corner buttons.
3. **Horizontal Dose Carousel:** Saving vertical screen real estate by scrolling today's doses horizontally allows the user to see their **Cabinet Stock** without excessive vertical scrolling.
4. **First-Class Family Profile Indicator:** The prominent chip **`F • Father (62 yrs • Diab & BP)`** right beneath the search bar visually validates the multi-profile architecture to examiners instantly.
5. **Urgency-Colored Badges:** High-contrast semantic colors (**Amber** for opened drops and **Red** for low stock) guide the eye effectively.

---

## 2. Micro-Features to Port from Variant 1

To make the master design a complete 10/10, the following four elements from Variant 1 should be incorporated:

1. **Context Menu (`⋮` Three Dots) on Cabinet Cards:**
   * *Why:* Each medicine card needs an accessible menu for quick actions: *"Edit Stock Count"*, *"Change Storage Location"*, *"Mark as Finished/Discarded"*, or *"View Leaflet"*.
2. **Voice Search Icon (`🎙️` Microphone):**
   * *Why:* Adding a microphone icon to the right of the search bar enhances accessibility, especially for elderly family members who prefer speaking names like *"Dolo"* or *"Acidity"*.
3. **Prescriber Context in Antibiotic Card:**
   * *Why:* Variant 1 includes *"Prescribed by Dr. R. Verma • Respiratory Relief"*. When managing multiple family prescriptions from different doctors, knowing *who* prescribed an active antibiotic regimen is essential medical context.
4. **Direct One-Tap "Add to Chemist List" Button:**
   * *Why:* In Variant 1, the low-stock item (*Meftal-Spas*) features an actionable button: `[ 🛒 Add to Chemist List ]`. In Variant 2, it only displays a static warning badge (`Low Stock • Restock`). Giving users a 1-tap shortcut to queue low-stock pills directly into the Chemist Cart is superior UX.

---

## 3. What Was Missing Entirely (PRD Features to Add)

Neither wireframe accounted for these three critical MedWise specifications:

### A. The Clinical Interaction Status Badge (Top-Level Safety)
* **The Missing Element:** MedWise's primary safety USP is checking drug-drug contraindications. On the home screen, there was no indicator showing whether the cabinet's active medications are safe together.
* **The Fix:** Place a compact, clickable status chip next to *"Offline Sync Ready"*:
  * 🟢 **Normal State:** `[ 🛡️ 0 Drug Conflicts ]`
  * 🔴 **Warning State:** `[ ⚠️ 1 Conflict: Aspirin + Warfarin ]` (Tapping opens the Safety Alert Modal).

### B. Storage Security Indicator (Privacy)
* **The Missing Element:** Medical data is sensitive and protected via `local_auth`. 
* **The Fix:** A subtle lock icon or encrypted badge (e.g., *"🔒 Biometric Protected & Encrypted"*) reassures the user that their health records are secure on-device.

### C. Interactive Symptom Filter Chips
* **The Missing Element:** For the *"2:00 AM Emergency Quick Finder"* feature, the search bar currently only has static text placeholder.
* **The Fix:** Add quick symptom shortcut chips directly beneath the search bar or within the cabinet filter bar:
  `[ 🌡️ Fever ]` `[ 🤢 Acidity ]` `[ 🤕 Headache ]` `[ 🩹 First Aid ]`
  Tapping `[Acidity]` instantly filters the list to show *Pantocid 40* and highlights its location: *"Fridge Door"*.

---

## 4. Final Flutter Widget Tree Blueprint

```
Scaffold
├── AppBar
│   ├── Leading: MedWise Logo + App Title
│   └── Actions: [🛡️ Safety Chip], [🔔 Notification Bell], [Profile Switcher]
│
└── SingleChildScrollView
    └── Column
        ├── SearchBar (Voice Mic + Barcode Scan Icons)
        ├── QuickSymptomChips ([Fever], [Acidity], [Pain], [Cough])
        │
        ├── AntibioticHeroCard
        │   ├── Title + "Day 3 of 5" Badge
        │   ├── Prescriber Subtitle ("Dr. R. Verma")
        │   ├── AnimatedLinearProgressIndicator (60%)
        │   └── Resistance Warning Callout Box
        │
        ├── QuickActionsRow (Row of 3 Cards)
        │   ├── [📷 Scan Strip / Box] (Primary Dark Teal Filled)
        │   ├── [🛒 Chemist Mode]
        │   └── [➕ Add Manually]
        │
        ├── SectionHeader ("Next Doses Today" + "View All")
        ├── HorizontalDoseCarousel (PageView / ListView.builder)
        │   └── DoseCard (Time, Pill Name, Dose Context, Full-Width [✓ Mark Taken] Button)
        │
        ├── SectionHeader ("Cabinet Stock" + Filter Icon)
        ├── StorageLocationFilterChips ([All], [Living Room], [Fridge], [First Aid])
        └── ListView.builder (CabinetItemCards)
            └── CabinetCard
                ├── Icon & Form Thumbnail
                ├── Brand Name + Active Salt Subtitle
                ├── Stock Count Pill + Expiry/Opened Badge
                ├── Physical Location Tag
                ├── ContextMenuButton (⋮)
                └── ConditionalRestockAction ([🛒 Add to Chemist List] if stock < 3)
```
