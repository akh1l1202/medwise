# MedWise — Product Requirements Document (PRD)

* **Document Version:** 1.0.0
* **Target Audience:** Engineering Evaluators, Project Mentors, Developers
* **Authors:** Akhil Tyagi & Project Team
* **Platform:** Mobile (Flutter / Android-First)

---

## 1. Problem Statement & Background

### 1.1 The Everyday Household Dilemma
In typical Indian households, family members visit doctors for common ailments (fever, gastrointestinal discomfort, respiratory infections, seasonal allergies). Each visit results in a new paper prescription. Patients proceed directly to the local pharmacy counter, purchasing complete 10- or 15-tablet blister strips. 

Meanwhile, at home:
* A drawer, plastic box, or refrigerator shelf holds dozens of half-used medicine strips.
* Consumers cannot remember what they own, where it is stored, or when it expires.
* Consumers do not know that **Dolo 650**, **Crocin 650**, and **Calpol 650** are pharmacologically identical (active salt: *Paracetamol 650mg*).
* Liquid suspensions, syrups, and ophthalmic drops are stored past their safe post-opening period (typically 28–30 days), posing medical hazards.
* Multiple prescriptions from different clinics result in accidental drug-drug interactions (e.g., combining blood thinners with OTC pain relievers).

### 1.2 Target Personas
1. **The Household Healthcare Manager:** Heads of family who purchase medicines for aging parents and children, struggling to track inventory across multiple rooms.
2. **The Chronic Care Patient:** Individuals taking daily maintenance pills (e.g., hypertension, diabetes) who need tight adherence and proactive refill warnings.
3. **The Budget-Conscious Student / Consumer:** Anyone who wants to stop burning money on repeat medicine strips at the pharmacy.

---

## 2. Core Feature Specifications

### Feature 1: The Digitized Home Medicine Cabinet
* **Purpose:** Maintain an accurate, offline-first digital representation of physical medicine stock.
* **Fields per Item:**
  * `id`: UUID
  * `brand_name`: String (e.g., *"Augmentin 625 Duo"*)
  * `active_salt`: String (e.g., *"Amoxicillin (500mg) + Clavulanic Acid (125mg)"*)
  * `strength`: String (e.g., *"625mg"*)
  * `form`: Enum (`Tablet`, `Capsule`, `Syrup`, `Ophthalmic Drop`, `Ointment`, `Inhaler`)
  * `quantity_remaining`: Decimal / Int (e.g., `7.0` tablets, or `60` ml)
  * `printed_expiry`: Date (`Month/Year`)
  * `opened_on_date`: Nullable Date (for liquids/drops)
  * `storage_location`: String tag (e.g., *"Living Room Drawer"*, *"Fridge Door"*, *"First Aid Kit"*)
  * `symptom_tags`: List<String> (e.g., `["Fever", "Body Pain"]`)
  * `assigned_profile_id`: Nullable UUID (links to a specific family member)

---

### Feature 2: Two-Pronged Medicine Ingestion Pipeline

#### Path A: Camera Strip/Box OCR with Fuzzy Confidence Engine
1. **Capture:** User snaps a photo of the printed medicine packaging or blister foil.
2. **On-Device Text Extraction:** Google ML Kit Text Recognition processes lines and blocks.
3. **Fuzzy String Matcher:** Compares raw OCR strings against the pre-bundled Indian Pharmaceuticals Database using **Dice's Coefficient** similarity.
4. **Confidence Scoring & Visual Badge:**
   * **High Match ($\ge 90\%$):** 🟢 Green badge with direct auto-fill.
   * **Medium Match ($70\% - 89\%$):** 🟠 Amber badge with *"Did you mean: [Suggested Match]?"*
   * **Low Match ($< 70\%$):** 🔴 Red badge flagging the field for manual confirmation.
5. **Mandatory Human-in-the-Loop Review Screen:** Users must verify the detected Brand Name, Strength, and Expiry Date before records are committed to local storage. Never auto-commit unverified raw OCR.

#### Path B: Fast Manual Autocomplete (Handwritten Prescription Fallback)
1. **The Reality:** Doctors' handwriting is notoriously illegible and fails mobile OCR.
2. **The Solution:** A high-speed search bar powered by local SQLite Full-Text Search (`FTS5`).
3. Typing just 2 characters (e.g., `"Me..."`) returns instant suggestions:
   * *Meftal-Spas (Mefenamic Acid + Dicyclomine)*
   * *Metformin 500mg*
   * *Metrogyl 400 (Metronidazole)*

---

### Feature 3: Chemist Counter "Smart Buy" Mode
* **Scenario:** User stands at the pharmacy holding a fresh prescription.
* **Workflow:**
  1. User selects or types the prescribed medicines into the "Chemist Cart".
  2. The **Active Salt Matcher** queries the home cabinet by pharmacological composition:
     $$\text{Prescribed: Dolo 650} \longrightarrow \text{Active Salt: Paracetamol 650mg} \longleftrightarrow \text{Cabinet Match: Crocin 650 (8 tabs)}$$
  3. **Strength Guard:**
     * If the user owns the identical salt but at a different concentration (e.g., prescribed 650mg, but owns 500mg), the app explicitly warns:
       > ⚠️ *"Same active salt found, but different strength (500mg vs. 650mg). Consult your doctor or chemist before substituting."*
  4. **Smart Purchase Recommendation:**
     * Prescribed: 10 tablets | Home Stock: 8 tablets | **Recommendation: Buy only 2 tablets (or 1 small strip).**
     * Shows estimated cost saved in Indian Rupees (₹).
  5. **Interactive Check-off List:** Users can tap items as the pharmacist hands them over.

---

### Feature 4: Intake Schedules & Auto-Depleting Inventory
* **Scheduled Alarms:** Push notifications triggered at specific times of day (Morning / Afternoon / Night) with food context (*Before Food / After Food*).
* **Actionable Notification Buttons:**
  * `[ Mark Taken ]`
  * `[ Snooze 15m ]`
  * `[ Skip ]`
* **Automatic Stock Decrement:** Tapping *"Mark Taken"* decrements the cabinet's `quantity_remaining` by the scheduled dosage amount.
* **Proactive Refill Warning:** When `quantity_remaining` drops below a 2-day threshold based on daily dosage, a notification triggers: *"Low Stock: Refill Metformin before Thursday."*

---

### Feature 5: Dual Expiry & Cabinet Cleanup Engine
1. **Printed Expiry Date:** Standard tracking with alerts 30 days and 7 days prior to expiry.
2. **The "Opened-On" Clock (Critical Domain Innovation):**
   * For eye drops, ear drops, and reconstituted pediatric antibiotic suspensions, the printed date is irrelevant once the seal is broken.
   * Tapping *"Mark Opened Today"* starts an internal 28-day countdown.
   * Upon day 28: A high-urgency alert fires: *"Dispose of Refresh Tears Eye Drops. 28-day open sterility period reached."*
3. **Cabinet Purge Mode:** Dedicated screen filtering all expired or soon-to-expire medications with guidance on safe disposal (preventing antibiotic water-table contamination).

---

### Feature 6: Antibiotic Course Adherence Tracker
* **Purpose:** Prevent premature stoppage of antibiotic regimens, which drives antimicrobial resistance.
* **Mechanism:**
  * When an antibiotic is registered, user defines course length (e.g., 5 days, twice daily).
  * Prominent home screen banner: **"Antibiotic Course: Day 3 of 5"**.
  * Shows clinical warning: *"Even if symptoms subside, complete all 5 days to prevent bacterial recurrence."*

---

### Feature 7: Curated Drug-Drug Interaction Safety Engine
* **Offline-First Dataset:** Bundles an audited JSON lookup table of 50–70 critical high-risk clinical pairs:
  * *NSAID + Anticoagulant (e.g., Aspirin + Warfarin $\rightarrow$ Severe internal bleeding hazard)*
  * *Dual NSAID (e.g., Ibuprofen + Diclofenac $\rightarrow$ Gastrointestinal ulceration)*
  * *ACE Inhibitor + Potassium Supplement $\rightarrow$ Hyperkalemia*
  * *Paracetamol Overdose Guard $\rightarrow$ Combining two multi-ingredient cold remedies that both contain Paracetamol*
* **Severity Levels:** `Critical / Red Alert`, `Moderate / Amber Warning`, `Informational`.
* **Ethical UI Disclaimer:** Transparently informs users: *"No interactions found in our limited offline reference table. Always consult your certified pharmacist or physician."*

---

### Feature 8: Family Profiles & Allergy Flags
* **Multi-User Architecture:** Single home cabinet partitioned into individual profiles (*Self*, *Spouse*, *Elderly Parent*, *Child*).
* **Allergy Safeguard:**
  * Each profile stores documented drug allergies (e.g., *"Penicillin / Beta-lactams"*, *"Sulfa drugs"*).
  * Adding a medicine whose salt falls into an allergic category triggers a block alert: *"Warning: Patient [Father] has a recorded allergy to Penicillin compounds."*

---

### Feature 9: Native Biometric Privacy Lock
* **Security:** Protects sensitive medical records using `local_auth` (Fingerprint / Face ID / Device PIN).
* App locks automatically upon backgrounding or app switch.

---

### Feature 10: 2:00 AM Emergency Symptom Finder
* Quick search input: *"Acidity"*, *"Headache"*, *"Nausea"*, *"Burn"*.
* Instantly filters active home stock by matched symptom tags and indicates the exact physical storage location (e.g., *"Gelusil Syrup is in Fridge Top Door"*).

---

### Feature 11: 1-Click Doctor Visit Medical Summary (Stretch Goal)
* Compiles current active medications, dosages, and documented allergies into a clean, printable PDF document via `pdf` and `printing` packages.

---

## 3. Scope & Prioritization Matrix (MoSCoW)

To prevent scope creep over a 3-4 week development sprint, features are strictly partitioned:

| Priority | Feature / Module | Rationale |
| :--- | :--- | :--- |
| **Must Have (P0 - MVP)** | Bundled Indian Medicines SQLite DB (FTS5 search) | Core foundation for offline autocomplete & brand-to-salt mapping. |
| **Must Have (P0 - MVP)** | Strip/Box Camera OCR + Fuzzy Confidence Scoring | Key technical differentiator; captures packaging text. |
| **Must Have (P0 - MVP)** | Mandatory OCR Review & Edit Screen | Human-in-the-loop safety; prevents noisy OCR auto-commits. |
| **Must Have (P0 - MVP)** | Home Cabinet Inventory Management (CRUD) | Essential local storage for active medicines. |
| **Must Have (P0 - MVP)** | Chemist Counter "Smart Buy" Mode | Primary value proposition: compares prescribed vs. home stock. |
| **Must Have (P0 - MVP)** | Active Salt Equivalence Engine & Strength Guard | Identifies identical compositions (Dolo $\leftrightarrow$ Crocin) and flags dosage differences (500mg vs 650mg). |
| **Must Have (P0 - MVP)** | Scheduled Dose Reminders with Auto-Depletion | Actionable notifications (`[Mark Taken]`) decrementing pill stock. |
| **Must Have (P0 - MVP)** | Curated Offline Drug Interaction Checker | Evaluates 50+ critical drug pairs with ethical UI disclaimers. |
| **Should Have (P1)** | "Opened-On" Clock for Drops & Syrups | 28-day countdown for eye drops and liquid suspensions. |
| **Should Have (P1)** | Antibiotic Course Adherence ("Day X of Y") | Prevents premature stoppage; includes resistance guidance. |
| **Should Have (P1)** | Biometric App Lock (`local_auth`) | Medical data privacy; showcases native device security. |
| **Should Have (P1)** | Profile-Based Allergy Alerts | Flags prescribed drugs matching family member allergy lists. |
| **Could Have (P2 - Stretch)** | 2:00 AM Symptom-Based Quick Finder | Tagging system to locate medicines by symptoms. |
| **Could Have (P2 - Stretch)** | 1-Click Doctor Visit PDF Export | Formatted summary for hospital and clinic visits. |
| **Could Have (P2 - Stretch)** | Cabinet Purge & Safe Disposal Guide | Environmental awareness for expired antibiotic disposal. |

---

## 4. Edge Cases & Clinical Safety Handling

1. **Cut Blister Strips (Missing Printed Expiry):**
   * If a patient has a cut foil strip where the expiry date portion was trimmed away, OCR cannot detect it.
   * *Resolution:* The review screen prompts: *"Expiry not detected. Tap to enter MM/YYYY or mark as 'Unknown/Consume Soon'"*.
2. **Direct Generic/Salt Prescriptions:**
   * Some doctors prescribe generic chemical names directly (e.g., *"Paracetamol 650mg"* instead of *"Dolo 650"*).
   * *Resolution:* The autocomplete search bar queries both `brand_name` and `active_salt` simultaneously via FTS5.
3. **Multi-Salt Combination Drugs:**
   * Many Indian formulations contain 2 or 3 active ingredients (e.g., *Amoxicillin + Clavulanic Acid*, or *Paracetamol + Phenylephrine + Chlorpheniramine*).
   * *Resolution:* The active salt field is tokenized. Equivalence requires a match across all active components and concentrations.
4. **Fractional Dosages (Half Tablets):**
   * Pediatric or tapered dosages often require taking half a tablet (0.5 tab).
   * *Resolution:* `quantity_remaining` and `dose_amount` are stored as floating-point numbers (`REAL`), allowing decrements of `0.5`, `0.25`, or liquid volumes (`5.0 ml`).
5. **Shared Cabinet vs. Profile Assignment:**
   * General household medicines (like band-aids, Paracetamol, antacids) are tagged as `Shared Household Stock`.
   * Personalized prescription drugs (e.g., *Thyronorm 50mcg*, *Metformin 500mg*) are bound to a specific family member profile to prevent dosage mix-ups.

---

## 5. Mathematical Formulations & Metrics

### 5.1 Chemist Bill Savings Metric
$$\text{Estimated Financial Savings (₹)} = \min(\text{Prescribed Quantity}, \text{Home Inventory Quantity}) \times \text{Unit Price per Tablet}$$

### 5.2 Antibiotic Course Adherence Rate
$$\text{Adherence Rate (\%)} = \left( \frac{\text{Doses Taken on Schedule}}{\text{Total Required Course Doses}} \right) \times 100$$

### 5.3 Dice's Bigram Similarity Metric (OCR Fuzzy Matcher)
$$\text{Similarity Score} = \frac{2 \times |B(\text{OCR Text}) \cap B(\text{Database Name})|}{|B(\text{OCR Text})| + |B(\text{Database Name})|}$$
Where $B(s)$ denotes the set of character bigrams in string $s$.
