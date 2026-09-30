# Chemist Counter Mode — Review & Implementation Specification

* **Master Wireframe:** [`docs/wireframes/chemist_mode_master.png`](./chemist_mode_master.png)
* **Alternative Variant:** [`docs/wireframes/chemist_mode_variant.png`](./chemist_mode_variant.png)
* **Design Standard Selected:** Screen 1 (Screen `efa86afe...`)

---

## 1. Why Screen 1 Was Selected as the Master

1. **The Instant Side-by-Side Equivalence Visualizer:**
   * Uses a clear comparative card:  
     `[Prescribed: Dolo 650 (Paracetamol 650mg)]` $\longleftrightarrow$ **`[ <-> SAME ]`** $\longleftrightarrow$ `[At Home: Crocin 650 (Paracetamol 650mg)]`
   * Solves the biggest challenge in explaining salt equivalence to non-medical users in 1 second.
2. **Visual Ratio Bar:**
   * A clean two-tone progress bar visually breaking down:
     * Dark teal: **8 tabs ready at home**
     * Light teal: **Buy only 2 tabs**
   * Eliminates the need to read dense numbers; users visually see that 80% of the course is already at home.
3. **Comprehensive Search Bar:**
   * Features both a clear `(X)` button and an explicit **`[📷 Scan Rx]`** button, supporting camera capture directly at the counter.
4. **Multi-Item Prescription Flow:**
   * Real-world prescriptions have multiple medications. Screen 1 includes a dedicated **`[+ Add another prescription item]`** button to manage an entire prescription checklist.
5. **Hyper-Local Indian Pharmacy Context:**
   * Includes badges: *"Strip cut approved"*, *"Unbroken foil"*, and practical pro-tips acknowledging that Indian chemists routinely cut blister strips for loose tablets.
6. **Complete Financial Transparency:**
   * Sticky bottom bar computes:
     * **Total Items to Buy:** 2 items (8 tabs)
     * **Total Financial Savings:** ₹78.00
     * **Final Estimated Bill:** ₹232.50

---

## 2. Micro-Touch from Variant 2 to Incorporate
* In the bottom navigation bar, style the Chemist beaker icon with a subtle **"Rx" badge** (`Chemist (Rx)`), reinforcing the prescription focus.

---

## 3. Flutter Widget Architecture for this Screen

```dart
Scaffold(
  appBar: MedWiseAppBar(
    title: "Chemist Counter Check",
    subtitle: "Verify home medicine box before paying",
    actions: [OfflineReadyBadge(), FamilyProfileAvatar()],
  ),
  body: SingleChildScrollView(
    padding: EdgeInsets.symmetric(horizontal: 16.0),
    child: Column(
      children: [
        // 1. Search Bar with Clear & Scan Rx buttons
        ChemistSearchBar(
          controller: searchController,
          onScanPressed: () => openPrescriptionScanner(),
        ),

        // 2. Exact Salt Detection Chip
        ActiveSaltBadge(saltName: "Paracetamol 650mg", category: "Antipyretic & Analgesic"),

        // 3. Hero Equivalence Card
        SaltEquivalenceCard(
          prescribedDrug: "Dolo 650 Tablet",
          prescribedQty: "10 Tablets (1 Strip)",
          homeMatchedDrug: "Crocin 650",
          homeAvailableQty: "8 tablets left",
          storageLocation: "Living Room Drawer #2",
          expiryStatus: "Oct 2026 (Unbroken foil)",
        ),

        // 4. Smart Counter Recommendation Card
        RecommendationCard(
          actionText: "Ask Chemist for: 2 Tablets",
          subtext: "Or 1 small blister pack cut strip instead of full box",
          savingsAmount: "₹78.00",
          homeStockRatio: 0.80, // 8 out of 10 ready at home
          strengthGuardMessage: "Paracetamol IP 650mg is bio-equivalent. Safe to consume home stock first.",
        ),

        // 5. Pharmacy Counter Checklist
        SectionHeader(title: "Pharmacy Counter Checklist", countBadge: "2 items listed"),
        PrescriptionChecklist(
          items: [
            ChecklistItem(
              name: "Dolo 650mg",
              toBuyText: "Buy 2 tabs only (Have 8 tabs of Crocin 650 at home)",
              price: "₹18.00",
              savedText: "Saved ₹78",
              badge: "Salt Matched • Strip cut approved",
              isChecked: true,
            ),
            ChecklistItem(
              name: "Augmentin 625 Duo",
              toBuyText: "0 tablets found in home cabinet",
              price: "₹214.50",
              badge: "New Course Required",
              isChecked: false,
            ),
          ],
        ),

        // 6. Add Item CTA
        OutlinedButton.icon(
          onPressed: () => addPrescriptionItem(),
          icon: Icon(Icons.add_circle_outline),
          label: Text("Add another prescription item"),
        ),

        // 7. Indian Pharmacy Pro-Tip Card
        PharmacyProTipCard(
          tipText: "Chemists routinely cut standard blister strips for loose tablets. Show this screen to avoid paying for excess medicines.",
        ),
      ],
    ),
  ),
  bottomNavigationBar: StickyCartBar(
    totalItems: "2 items (8 tabs)",
    totalSaved: "₹78.00",
    estimatedBill: "₹232.50",
    actionButton: FilledButton.icon(
      icon: Icon(Icons.update),
      label: Text("Update Cabinet"),
      onPressed: () => applyPurchasesToCabinet(),
    ),
  ),
)
```
