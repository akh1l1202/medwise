<div align="center">
  <img src="assets/images/logo.jpg" alt="MedWise Logo" width="160" style="border-radius: 24px;" />
  <h1>MedWise</h1>
  <p><strong>Offline-first mobile medicine cabinet, active salt equivalence matcher, and smart chemist-counter companion for Indian households.</strong></p>
</div>

---

## 📌 Executive Summary
**MedWise** is an engineering mini-project built with Flutter (Dart). It solves a ubiquitous real-world problem: **unnecessary duplicate purchases and pharmaceutical waste in Indian households.** 

People regularly visit doctors, receive prescriptions, and buy complete new medicine strips at the pharmacy—completely oblivious to the fact that they already have half-used strips of the exact same medicine (or an equivalent brand with identical active ingredients) sitting at home in a medicine drawer.

MedWise transforms a chaotic home medicine stash into an intelligent, digitized inventory. It features:
1. **Camera Strip OCR with Fuzzy Confidence Scoring** & Instant Autocomplete.
2. **Chemist Counter "Smart Buy" Mode** with Active Salt Matching (e.g., *Dolo 650 $\leftrightarrow$ Crocin 650*).
3. **Auto-Depleting Intake Schedules** (decrementing stock upon marking doses as taken).
4. **"Opened-On" Expiry Engine** for syrups and eye drops.
5. **Antibiotic Course Adherence** ("Day X of Y" to prevent antimicrobial resistance).
6. **Curated Offline Drug-Drug Interaction Safety Engine**.
7. **Biometric Privacy Lock** via `local_auth`.

---

## 🗂️ Documentation Directory

| Document | Purpose |
| :--- | :--- |
| [**`docs/PRD.md`**](./docs/PRD.md) | **Product Requirements Document**: Detailed functional specifications, user personas, workflows, edge cases, and feature matrix. |
| [**`docs/TECHNICAL_ARCHITECTURE.md`**](./docs/TECHNICAL_ARCHITECTURE.md) | **Technical Architecture**: Data models, SQLite/Drift schema, Indian medicine dataset strategy, OCR fuzzy-matching algorithms, and package configurations. |
| [**`docs/ROADMAP_AND_VIVA.md`**](./docs/ROADMAP_AND_VIVA.md) | **Execution & Evaluation Guide**: 3-4 week sprint roadmap, technical trap mitigation, and step-by-step viva presentation script. |
| [**`docs/PROJECT_IDEATION_AND_COMPETITIVE_ANALYSIS.md`**](./docs/PROJECT_IDEATION_AND_COMPETITIVE_ANALYSIS.md) | **Gap Analysis & Decision Log**: Proof of 0% batch overlap, NLM API & RxNorm pitfall documentation, and handwritten OCR rationale. |
| [**`docs/wireframes/`**](./docs/wireframes/README.md) | **UI/UX Wireframe Suite**: All 5 master wireframes generated via Stitch, design tokens, and Flutter widget implementation blueprints. |

---

## 🚀 Key Differentiators vs. Generic Medical Apps

| Traditional Apps | MedWise |
| :--- | :--- |
| Dependent on US-centric APIs (RxNorm / discontinued NLM endpoints). | **100% Offline-First**: Pre-bundled SQLite database of Indian pharmaceuticals (brands + active salts). |
| Expects camera to read doctors' illegible handwriting. | **Pragmatic Ingestion**: Strip OCR on printed boxes + lightning-fast autocomplete for handwritten slips. |
| Blind string matching ("Dolo" $\neq$ "Crocin"). | **Active Salt Equivalence Engine**: Detects that Dolo and Crocin share the same salt (*Paracetamol 650mg*). |
| Relies only on printed expiration dates. | **Dual Expiry Logic**: Tracks printed dates *plus* 30-day "Opened-On" clocks for eye drops and syrups. |
| Passive lists that go out of date. | **Living Inventory**: Doses marked "Taken" automatically decrement pill count in the cabinet. |

---

## 🛠️ Core Tech Stack
* **Framework:** Flutter (Targeting Android & iOS)
* **Language:** Dart 3.x
* **State Management:** `flutter_riverpod` (Repository + AsyncNotifier pattern)
* **Local Storage & Database:** `drift` / `sqflite` (with FTS5 Full-Text Search) + `hive`
* **On-Device Machine Learning:** `google_mlkit_text_recognition`
* **Text Similarity & Matching:** `string_similarity` (Dice's Coefficient / Levenshtein Distance)
* **Background Alarms & Notifications:** `flutter_local_notifications` + `timezone`
* **Device Security:** `local_auth` (Fingerprint / Face Unlock)
