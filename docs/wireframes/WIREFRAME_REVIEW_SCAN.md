# OCR Scan Review & Confirmation — Review & Implementation Specification

* **Master Wireframe:** [`docs/wireframes/scan_review_master.png`](./scan_review_master.png)
* **Alternative Variant:** [`docs/wireframes/scan_review_variant.png`](./scan_review_variant.png)
* **Design Standard Selected:** Screen 1 (Screen `dbbe271a...`)

---

## 1. Why Screen 1 Was Selected as the Master

1. **Cross-Cabinet Clinical Safety Warning:**
   * Features the standout callout:  
     `ℹ Matches household fever stock (Crocin, Calpol). Avoid double dosing.`
   * Solves a real-world clinical danger: a user scanning a new strip of Dolo might not realize they have Crocin in their drawer, and could accidentally take both within hours.
2. **Color-Coded Semantic Bounding Boxes:**
   * Clearly delineates extracted text on the blister pack photo:
     * **Cyan Box:** `• DOLO 650 [94%]` (Brand Name)
     * **Amber Box:** `• EXP 10/26 [88%]` (Expiry Date)
     * **Yellow Box:** Batch details
   * Visually proves to evaluators how Google ML Kit bounding box coordinates map directly to form fields below.
3. **Data Privacy Reassurance:**
   * Top banner: `⚡ Local On-Device OCR • No data leaves phone`.
   * Essential for defending medical privacy during project vivas.
4. **Official Pharmacopoeia Reference:**
   * Shows `Matched with Indian Pharmacopoeia Database (IP-8402)`, reinforcing that the app uses a legitimate standardized pharmaceutical catalog.

---

## 2. Micro-Details from Variant 2 to Incorporate
1. **Explicit Expiry Date Card Formatting:**
   * Use Variant 2's clean calendar input: `[ 10 / 2026 📅 ]` with tag `🏷️ Detected from batch stamp` and safety status `Valid & Safe`.
2. **"Human-in-the-Loop Review" Subtitle:**
   * Use this academic term in the header to explain the ethical requirement for manual confirmation before committing OCR results to local health storage.

---

## 3. Flutter Widget Architecture for this Screen

```dart
Scaffold(
  appBar: AppBar(
    leading: BackButton(),
    title: Text("Review Scan Details"),
    actions: [TextButton(onPressed: () => cancelScan(), child: Text("Cancel"))],
    bottom: PreferredSize(
      preferredSize: Size.fromHeight(32.0),
      child: PrivacyBanner(text: "Local On-Device OCR • No data leaves phone"),
    ),
  ),
  body: SingleChildScrollView(
    padding: EdgeInsets.all(16.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Interactive Image Preview with Bounding Box Overlays
        ImageBoundingBoxOverlay(
          imageFile: capturedBlisterPackImage,
          boundingBoxes: [
            OcrBoundingBox(rect: nameRect, label: "DOLO 650 [94%]", color: Colors.cyan),
            OcrBoundingBox(rect: expiryRect, label: "EXP 10/26 [88%]", color: Colors.amber),
          ],
          actions: [
            IconButton(icon: Icon(Icons.crop), onPressed: () => recropImage()),
            IconButton(icon: Icon(Icons.fullscreen), onPressed: () => openFullscreen()),
          ],
        ),

        SectionHeader(
          title: "Extracted Medicine Details",
          subtitle: "Tap any field to edit or correct OCR reading",
          badge: "Auto-Detected",
        ),

        // 2. Brand Name Field with Confidence Badge
        OcrReviewCard(
          label: "BRAND NAME",
          confidenceScore: 0.94, // 94% High Match
          child: TextFormField(
            initialValue: "Dolo 650 Tablet",
            decoration: InputDecoration(suffixIcon: Icon(Icons.edit_outlined)),
          ),
          footnote: "Matched with Indian Pharmacopoeia Database (IP-8402)",
        ),

        // 3. Active Composition Card with Cross-Cabinet Warning
        ActiveCompositionCard(
          saltName: "Paracetamol (650 mg)",
          category: "Antipyretic & Analgesic",
          statusBadge: "Verified",
          crossCabinetWarning: "Matches household fever stock (Crocin, Calpol). Avoid double dosing.",
        ),

        // 4. Expiry Date Card
        ExpiryReviewCard(
          initialExpiry: "10 / 2026",
          statusText: "Valid (32 months remaining)",
          tag: "Detected from batch stamp",
        ),

        // 5. Quantity & Storage Location Inputs
        QuantityStepper(initialValue: 10, unit: "tablets"),
        StorageLocationPicker(selectedLocation: "Living Room Drawer #2"),
      ],
    ),
  ),
  bottomNavigationBar: StickyDualActionBar(
    leftButton: OutlinedButton.icon(
      icon: Icon(Icons.camera_alt_outlined),
      label: Text("Retake"),
      onPressed: () => retakePhoto(),
    ),
    rightButton: FilledButton.icon(
      icon: Icon(Icons.check),
      label: Text("Confirm & Save"),
      onPressed: () => saveToCabinet(),
    ),
  ),
)
```
