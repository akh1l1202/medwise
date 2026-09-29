# MedWise — Competitive Gap Analysis & Engineering Decision Log

> **Defensible analysis of batch uniqueness (0% overlap) and technical justifications for key architectural pivots.**

---

## 1. Competitive Gap Analysis (0% Batch Overlap)

An audit of all registered mini-projects in the Flutter Honours batch was conducted to ensure MedWise occupies a completely distinct, defensible, and untouched niche.

### 1.1 Batch Theme Clustering

| Domain Cluster | Existing Batch Projects | Why MedWise Has Zero Overlap |
| :--- | :--- | :--- |
| **Mobile Gaming & Reflex** | *Ghosted, ChromaQuest, TrailShift, Gambit, Mayday, CodeWar, Tap Rush, Prison Break* (8 apps) | MedWise is a high-utility, real-world healthcare companion, completely avoiding entertainment and casual gaming. |
| **Personal Diaries & Scrapbooks** | *Flipfolio, MindSphere, Memories* (3 apps) | MedWise does not handle photo albums or emotional journaling; it is a clinical and inventory management tool. |
| **Live Collaboration & Rooms** | *CloudDocs (Docs), JamRoom (Music), Beacon (Scavenger hunt)* (3 apps) | MedWise is an offline-first personal/family utility rather than a live multi-device party/collaboration room. |
| **Fitness & Habit Trackers** | *RoutePulse (GPS Running), Loopin (Habit Heatmaps)* (2 apps) | MedWise focuses on medical adherence, prescription inventory, and active salt substitution, not general fitness routines. |
| **Shopping & Decision Consensus** | *Haven (Moodboard/Shopping), LGTM (Group Swipe Consensus)* (2 apps) | MedWise functions strictly at the pharmacy counter to prevent unnecessary duplicate purchases based on chemical composition. |

### 1.2 The Untouched Problem Space
MedWise is the **only project in the entire batch** addressing:
* **Domestic pharmaceutical waste** and unorganized home medicine storage.
* **Chemist counter overspending** by verifying existing home stock before purchase.
* **Active salt equivalence** (mapping trade names to chemical formulations, e.g., *Dolo 650 $\leftrightarrow$ Crocin 650*).
* **Clinical safety safeguards** (drug contraindications, dual-expiry tracking, and antibiotic adherence).

---

## 2. Engineering Pitfalls & Architectural Decision Log

During technical review and pressure-testing, three critical platform and data traps were identified and resolved:

---

### 2.1 The NLM Drug Interaction API Discontinuation (January 2024)

* **The Initial Plan:** Rely on the US National Library of Medicine's (NLM) public REST endpoint (`rxnav.nlm.nih.gov/REST/interaction/list.json`) to dynamically query drug-drug interactions.
* **The Pitfall:** The NIH/NLM **officially discontinued the Drug-Drug Interaction API on January 2, 2024**, and removed the Interactions feature from RxNav after their data agreement with DrugBank expired. Building on this endpoint would result in runtime `404 Not Found` or HTTP connection errors during live evaluation.
* **The Engineering Pivot:**
  * **Bundled Curated Offline Dataset:** MedWise embeds an audited local JSON table (`assets/data/drug_interactions.json`) covering 50+ critical, high-risk clinical pairs (*e.g., NSAID + Anticoagulant, Dual NSAIDs, Metformin + Alcohol, Paracetamol multi-product toxicity*).
  * **Zero Network Dependency:** The safety engine runs 100% on-device with sub-millisecond evaluation ($O(N \times M)$ where $N \le 20$ cabinet items and $M \approx 60$ rules).
  * **Ethical UI Framing:** Instead of falsely claiming "zero conflicts" from an incomplete online database, the UI displays transparent, medically responsible disclaimers: *"No interactions found in our limited offline reference table. Always consult your certified pharmacist."*

---

### 2.2 RxNorm US-Only Vocabulary vs. Indian Pharmaceutical Brands

* **The Initial Plan:** Query the RxNorm API to look up generic salts and chemical formulations.
* **The Pitfall:** RxNorm is strictly bound to the US National Drug Code (NDC) directory. Indian commercial trade names (*e.g., Dolo 650, Crocin, Calpol, Meftal-Spas, Pantocid, Augmentin*) do not exist in RxNorm, meaning any brand-to-salt query to a US API returns empty results.
* **The Engineering Pivot:**
  * **Bundled Indian Pharmacopoeia Database:** MedWise bundles an optimized, compressed SQLite database (`assets/database/indian_medicines.db`) derived from public Indian pharmaceutical datasets (1mg/Kaggle) covering the top ~3,000–5,000 common Indian formulations.
  * **Full-Text Search (FTS5):** Indexed virtual tables allow sub-millisecond offline lookup mapping Indian brand names directly to their active chemical composition (`brand_name` $\rightarrow$ `active_salt` $\rightarrow$ `strength`).
  * **Reliability:** The core feature (*"You don't have Dolo, but you have Crocin, which shares the same active salt Paracetamol 650mg"*) functions completely offline in clinic basements and pharmacy counters.

---

### 2.3 Rationale: Rejecting Handwritten OCR in Favor of Strip OCR + Autocomplete

* **The Initial Plan:** Use camera OCR (Google ML Kit) to scan and extract text from doctors' paper prescriptions.
* **The Pitfall:** Doctors' handwriting is notoriously illegible and highly unstandardized. Even advanced machine learning vision models exhibit $< 15\%$ character accuracy on cursive, hastily scribbled medical slips. Relying on handwritten OCR introduces severe demo failure risks and potential medical misclassification.
* **The Engineering Pivot:**
  1. **Commercial Packaging & Strip OCR Only:** ML Kit Text Recognition is strictly scoped to **printed foil blister strips and commercial packaging boxes**, where font typography, high contrast, and batch stamping (`EXP 08/26`) can be reliably parsed.
  2. **Human-in-the-Loop Review Screen:** Scanned text is never blindly committed. It is processed through a fuzzy matching engine (Dice's Coefficient) against the local Indian database, assigned a mathematical confidence badge (🟢 High $\ge 90\%$, 🟠 Suggested $70-89\%$, 🔴 Low $< 70\%$), and presented on an editable confirmation screen.
  3. **High-Speed Autocomplete Fallback:** For handwritten prescriptions, users type the first 2 letters into an FTS5 search bar. Instant autocomplete suggestions eliminate typing friction while maintaining 100% data integrity.
