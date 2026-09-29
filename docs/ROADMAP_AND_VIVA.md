# MedWise — Implementation Roadmap & Viva Presentation Guide

---

## 1. 4-Week Sprint Implementation Roadmap

### Sprint 1 (Week 1): Data Ingestion & Local Database Setup
* [x] **Project Scaffolding:** Set up Flutter project with clean feature-first architecture (`data/`, `domain/`, `presentation/`).
* [x] **Indian Medicine Dataset Curation:** Preprocess Kaggle 1mg Indian medicines CSV into an optimized SQLite database (`indian_medicines.db`) with FTS5 virtual tables.
* [x] **Asset Bundling:** Place database in `assets/database/` and implement database copy-to-cache logic on first app launch.
* [x] **Cabinet CRUD:** Implement local user cabinet tables using `sqflite` (Add, Read, Update, Delete medicines).
* [x] **Home Screen UI:** Build the main cabinet dashboard displaying active items, expiry indicators, and quantity pills.

---

### Sprint 2 (Week 2): OCR Pipeline & Fuzzy Matching Engine
* [x] **Camera & Gallery Integration:** Set up `image_picker` to capture clear photos of medicine blister packs and packaging boxes.
* [x] **ML Kit Text Recognition:** Extract text blocks and lines on-device using `google_mlkit_text_recognition`.
* [x] **Fuzzy String Matcher:** Implement Dice's coefficient algorithm via `string_similarity` to calculate confidence percentages against the preloaded SQLite database.
* [x] **OCR Review Screen:** Build the human-in-the-loop review interface with color-coded confidence badges (🟢 High, 🟠 Suggested, 🔴 Low/Manual).
* [x] **Manual Autocomplete:** Build the high-speed FTS5 search bar for handwritten prescription lookups.

---

### Sprint 3 (Week 3): The Chemist Counter & Domain Intelligence
* [x] **Chemist Counter "Smart Buy" Mode:** Build the interface to input prescribed medicines.
* [x] **Active Salt Equivalence Engine:** Query the home cabinet for matching active salts and compare concentrations.
* [x] **Strength Guard Logic:** Implement comparison checks (e.g., alert when 500mg $\neq$ 650mg).
* [x] **Interactive Purchase Checklist:** Display quantities to buy, quantities already owned at home, and estimated ₹ savings.
* [x] **Curated Drug Interaction Checker:** Load `drug_interactions.json` and flag conflicting combinations.

---

### Sprint 4 (Week 4): Notifications, Adherence & Final Polish
* [x] **Scheduled Alarms:** Configure `flutter_local_notifications` with timezone support for exact dose timings.
* [x] **Auto-Depletion Hook:** Connect the *"Mark Taken"* action to automatically decrement remaining tablet counts.
* [x] **"Opened-On" Engine:** Implement the 28-day countdown clock for liquid suspensions and ophthalmic drops.
* [x] **Antibiotic Tracker:** Implement the *"Day X of Y"* adherence widget.
* [x] **Biometric App Lock:** Integrate `local_auth` for medical privacy.
* [x] **Viva Demo Script Rehearsal & Edge Case Hardening.**

---

## 2. Technical Traps & Pitfalls Avoided

| Potential Trap | Why It Would Have Failed | How MedWise Solves It |
| :--- | :--- | :--- |
| **NLM Drug Interaction API** | Shut down by the US National Library of Medicine in January 2024. | Uses an embedded, audited offline JSON dataset of 50+ critical drug pairs. Zero network calls, zero downtime. |
| **RxNorm API for Indian Brands** | RxNorm only indexes US NDC formulations. Searching Indian brands like *Dolo, Crocin, Meftal-Spas, Pantocid* returns `404 Not Found`. | Bundles a dedicated Indian Pharmacopoeia SQLite database with pre-indexed Indian trade names and active salts. |
| **Handwritten Prescription OCR** | Doctors' handwriting is notoriously illegible; camera OCR accuracy is $< 15\%$, leading to embarrassing viva demo crashes. | Pragmatic separation: Strip/Box OCR for printed packaging + sub-millisecond FTS5 autocomplete for handwritten slips. |
| **Silent OCR Misclassification** | Committing noisy OCR text directly to the database could store incorrect dosages or medicine names. | Mandatory **OCR Review Screen** with mathematical confidence scoring giving the user final verification authority. |
| **Android 12+ Background Service Termination** | Standard timers get terminated by Android OEM battery optimization (MIUI/OneUI/ColorOS). | Declares `SCHEDULE_EXACT_ALARM` permissions and uses native system alarms via `flutter_local_notifications`. |

---

## 3. The Winning 3-Minute Live Viva Demo Script

Follow this exact sequence in front of the professors:

### Step 1: The Everyday Dilemma (30 Seconds)
* **What to say:**
  > *"Respected professors, Indian families waste thousands of rupees annually because medicine drawers are unorganized, and at the chemist counter, we can't remember what we already own. MedWise is an offline-first companion that solves this."*
* **What to show:** Open the app using **Biometric Fingerprint Unlock** (`local_auth`). Show a clean Home Cabinet populated with 5 common household medicines (e.g., *Crocin 650, Pantocid 40, Cetirizine 10mg*).

### Step 2: The Chemist Counter "Smart Buy" Demo (60 Seconds)
* **What to say:**
  > *"Imagine I just came from a clinic. The doctor prescribed Dolo 650 (10 tablets). I am standing at the chemist counter."*
* **What to do:**
  1. Open **"Chemist Counter Mode"**.
  2. Type *"Dolo"* in the autocomplete search bar. Tap *"Dolo 650"*.
  3. **The 'Aha!' Moment:** The screen instantly displays:
     > 💡 *"You already have 8 tablets of Crocin 650 (Same Active Salt: Paracetamol 650mg) in your Living Room Drawer! Buy only 2 tablets."*
  4. Explain to the evaluator: *"The app didn't do a naive name match. It mapped Dolo 650 to its pharmacological composition and checked active home stock."*

### Step 3: Strip OCR with Confidence Scoring (45 Seconds)
* **What to say:**
  > *"When adding a new medicine box or foil strip to the home stash, users don't have to type."*
* **What to do:**
  1. Tap *"Scan Strip"*. Point the camera at a printed medicine box.
  2. Show the **OCR Review Screen**: Show the green **94% Confidence Badge** matched against the local Indian database, along with the extracted expiry date.
  3. Show how the user can edit or confirm before saving.

### Step 4: The Domain Depth Touches (45 Seconds)
* **What to say & show:**
  1. **Opened-On Clock:** Show an eye drop item: *"Opened 12 days ago — 16 days of safe sterility remaining."*
  2. **Drug Interaction Warning:** Add *Aspirin* while *Warfarin* is active. Show the prominent clinical safety alert.
  3. **Auto-Depletion:** Tap *"Mark Taken"* on a daily reminder, showing the quantity drop from 8 to 7 tablets.

---

## 4. Anticipated Evaluator Questions & Bulletproof Answers

#### Q1: "Why did you build an offline-first app instead of using Firebase or a cloud backend?"
> **Answer:** *"Healthcare decisions happen in hospital basements, rural clinics, and chemist counters where 4G/5G mobile signals frequently drop. Furthermore, medical data is deeply personal. By bundling our Indian pharmaceutical dataset locally in SQLite and storing the cabinet on-device, MedWise is 100% private, operates with zero latency, and never fails due to network outages."*

#### Q2: "How does your active salt matching handle different strengths?"
> **Answer:** *"Our database stores active salt and strength as distinct fields. If a patient is prescribed Paracetamol 650mg and has Paracetamol 500mg at home, our Strength Guard flags that the active chemical is identical but the concentration differs, advising the patient to consult their doctor or pharmacist rather than blindly swapping dosages."*

#### Q3: "What happens if a medicine is not in your bundled database?"
> **Answer:** *"Our bundled database covers the top 3,000–5,000 high-frequency Indian formulations. However, if a rare or newly launched drug is scanned, our fuzzy matcher yields a low confidence score ($< 70\%$). The app automatically prompts the user to enter the brand name and salt manually, which is then saved to their personal cabinet."*

#### Q4: "How did you calculate the OCR confidence score?"
> **Answer:** *"We use Dice's Coefficient (bigram string similarity) comparing the raw text blocks extracted by Google ML Kit against our local pharmacopoeia database. This calculates a mathematical overlap score from 0.0 to 1.0, categorizing results into High ($\ge 90\%$), Suggested ($70-89\%$), or Low confidence."*
