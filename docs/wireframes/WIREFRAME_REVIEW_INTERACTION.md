# Drug Interaction Safety Alert — Review & Implementation Specification

* **Master Wireframe:** [`docs/wireframes/interaction_alert_master.png`](./interaction_alert_master.png)
* **Alternative Variant:** [`docs/wireframes/interaction_alert_variant.png`](./interaction_alert_variant.png)
* **Design Standard Selected:** Screen 1 (Screen `3a21b24b...`)

---

## 1. Why Screen 1 Was Selected as the Master

1. **Complete, Flawless BottomSheet Presentation:**
   * Unlike Screen 2 (which suffered from rendering clipping and missing the top half), Screen 1 is a complete, production-ready BottomSheet modal with a dimmed contextual background.
2. **The "Critical Clash" Visualizer:**
   * Features a striking side-by-side conflict card:
     * **Left Drug:** `Aspirin 75mg (Antiplatelet)` with badge `Added Just Now`
     * **Center Clash Element:** Red lightning bolt badge: `⚡ CRITICAL CLASH`
     * **Right Drug:** `Warfarin 5mg (Anticoagulant)` with physical storage location `Master Bed Drawer`
   * Instantly clarifies *why* the alert fired: the newly scanned medicine conflicts with a medicine already sitting in the patient's bedroom drawer.
3. **Structured Clinical Explanation:**
   * **Mechanism & Risk:** Explicitly explains *why* the combination is dangerous (*"substantially multiplies the risk of severe gastrointestinal bleeding, ulceration, and internal hemorrhaging"*).
   * **Actionable Recommendation:** Clear medical directive (*"Do not administer both without explicit clearance and INR blood monitoring from your cardiologist"*).
4. **Offline Rule Compliance & Ethical Disclaimer:**
   * Notes: `Cross-checked against MedWise Offline Clinical Rules (v4.2). Informational safety alert; does not replace qualified physician care.`
5. **Decisive Action Buttons:**
   * **Primary Destructive Action:** `[ 🗑 Remove Conflicting Medicine ]` (solid red) to prevent accidental ingestion.
   * **Secondary Action:** `[ 📞 Acknowledge & Consult Doctor ]` (outlined dark) to call or consult a physician.

---

## 2. Flutter Widget Architecture for this Modal

```dart
void showDrugInteractionModal(
  BuildContext context, {
  required String newDrugName,
  required String newDrugClass,
  required String existingDrugName,
  required String existingDrugClass,
  required String existingLocation,
  required String clinicalMechanism,
  required String recommendation,
  required VoidCallback onRemove,
  required VoidCallback onConsultDoctor,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      padding: EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
            ),
          ),
          SizedBox(height: 16),

          // Header with Warning Tag & Close Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Badge(
                backgroundColor: Color(0xFFFEE2E2),
                label: Text("🛡️ CLINICAL SAFETY WARNING", style: TextStyle(color: Color(0xFFDC2626))),
              ),
              IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          SizedBox(height: 8),

          Text(
            "Severe Drug Interaction Detected",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            "A newly scanned or added medication conflicts with existing active medicine in your household cabinet.",
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          SizedBox(height: 16),

          // Hero Clash Visualizer Card
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Color(0xFFFCA5A5)),
              borderRadius: BorderRadius.circular(16),
              color: Color(0xFFFFF5F5),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    DrugSideCard(name: newDrugName, drugClass: newDrugClass, tag: "Added Just Now"),
                    ClashBadge(text: "CRITICAL CLASH"),
                    DrugSideCard(name: existingDrugName, drugClass: existingDrugClass, tag: existingLocation),
                  ],
                ),
                Divider(height: 24, color: Color(0xFFFECACA)),
                ClinicalRiskBox(mechanism: clinicalMechanism),
                SizedBox(height: 8),
                RecommendationBox(text: recommendation),
              ],
            ),
          ),
          SizedBox(height: 16),

          // Disclaimer Footer
          ComplianceNote(
            text: "Cross-checked against MedWise Offline Clinical Rules (v4.2). Informational safety alert; does not replace qualified physician care.",
          ),
          SizedBox(height: 20),

          // Action Buttons
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Color(0xFFDC2626), minimumSize: Size.fromHeight(50)),
            icon: Icon(Icons.delete_outline),
            label: Text("Remove Conflicting Medicine"),
            onPressed: onRemove,
          ),
          SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: Size.fromHeight(50)),
            icon: Icon(Icons.phone_outlined),
            label: Text("Acknowledge & Consult Doctor"),
            onPressed: onConsultDoctor,
          ),
        ],
      ),
    ),
  );
}
```
