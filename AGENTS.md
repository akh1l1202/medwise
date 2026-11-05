# MedWise — Agent Context & Project Guidelines

> **Project:** MedWise (Offline-First Medicine Cabinet & Smart Chemist-Counter Companion)  
> **Repository:** `D:\GitHub\medwise`  
> **Original Ideation & Wireframe Thread:** [Ideation & Wireframing Conversation](conversation://16918bb9-2748-44c5-8033-7aebfd4c3270)

---

## 📌 Executive Overview
MedWise is an offline-first mobile healthcare application built in Flutter (Dart) for Indian households. It prevents duplicate medicine purchases at chemist counters by checking prescribed drugs against active home inventory using active salt equivalence (e.g., *Dolo 650 $\leftrightarrow$ Crocin 650 = Paracetamol 650mg*).

---

## 🧭 Project Status
* **Ideation & Gap Analysis:** ✅ Completed (0% batch overlap).
* **PRD & Requirements:** ✅ Completed in [`docs/PRD.md`](./docs/PRD.md).
* **Technical Architecture:** ✅ Completed in [`docs/TECHNICAL_ARCHITECTURE.md`](./docs/TECHNICAL_ARCHITECTURE.md).
* **Implementation Roadmap & Viva Script:** ✅ Completed in [`docs/ROADMAP_AND_VIVA.md`](./docs/ROADMAP_AND_VIVA.md).
* **UI/UX Wireframes Suite (All 5 Master Screens):** ✅ Completed in [`docs/wireframes/`](./docs/wireframes/README.md).
* **Next Phase:** Flutter project scaffolding & database initialization.

---

## 🛠️ Architecture & Technical Rules for Agents
When working on code or features in this project, strictly adhere to these architectural decisions:

1. **100% Offline-First:**
   * Never rely on external US APIs like RxNorm or the discontinued NLM Interaction API.
   * Use the bundled SQLite database (`assets/database/indian_medicines.db`) with FTS5 virtual tables for all drug and salt lookups.
   * Use `assets/data/drug_interactions.json` for curated clinical safety checks.
2. **State Management:**
   * Use `flutter_riverpod` with `AsyncNotifier` and the repository pattern.
3. **OCR Ingestion Pipeline:**
   * Restrict Google ML Kit OCR to printed packaging and blister foils.
   * Always route OCR results through the fuzzy string matching algorithm (Dice's Coefficient via `string_similarity`) and display confidence badges (🟢 $\ge 90\%$, 🟠 $70-89\%$, 🔴 $< 70\%$).
   * Never auto-commit raw OCR; always present the editable **Human-in-the-Loop Review Screen**.
   * Use FTS5 autocomplete as the primary input path for handwritten doctor slips.
4. **Design Tokens:**
   * Primary: Deep Emerald Teal (`#0F766E` / `#14B8A6`).
   * Surfaces: Soft Gray (`#F8FAFC`) with crisp white elevated cards (`#FFFFFF`, `16px` corner radius).
   * Semantics: Green (`#10B981`) for Safe/High-Confidence, Amber (`#F59E0B`) for Caution, Red (`#EF4444`) for Conflicts/Low-Stock.
5. **Exact Dose Alarms:**
   * Use `flutter_local_notifications` with `timezone` and ensure Android 12+ `SCHEDULE_EXACT_ALARM` permissions.
   * Tapping *"Mark Taken"* must automatically decrement the cabinet's `quantity_remaining`.

---

## 🗂️ Core Documentation Quicklinks
* [Product Requirements Document (PRD)](./docs/PRD.md)
* [Technical Architecture & DB Schemas](./docs/TECHNICAL_ARCHITECTURE.md)
* [Sprint Roadmap & Viva Demo Script](./docs/ROADMAP_AND_VIVA.md)
* [Competitive Gap Analysis & Decision Log](./docs/PROJECT_IDEATION_AND_COMPETITIVE_ANALYSIS.md)
* [UI/UX Wireframe Master Suite](./docs/wireframes/README.md)
