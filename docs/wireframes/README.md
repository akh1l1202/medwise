# MedWise — UI/UX Wireframe & Design Specification Suite

This directory contains the complete set of master wireframes and technical implementation specifications for **MedWise**, generated via Google Stitch and verified for production Flutter implementation.

---

## 📱 The 5 Core Master Screens

| Screen # | Screen Name | Master Wireframe Asset | Detailed Technical Specification | Core Architectural Features |
| :---: | :--- | :--- | :--- | :--- |
| **01** | **Home Dashboard & Inventory** | [`home_dashboard_master.png`](./home_dashboard_master.png) | [`WIREFRAME_REVIEW_HOME.md`](./WIREFRAME_REVIEW_HOME.md) | Antibiotic adherence hero banner, primary "Scan Strip" CTA, horizontal today's doses carousel, storage location tabs, and family profile indicator. |
| **02** | **Chemist Counter "Smart Buy"** | [`chemist_mode_master.png`](./chemist_mode_master.png) | [`WIREFRAME_REVIEW_CHEMIST.md`](./WIREFRAME_REVIEW_CHEMIST.md) | Side-by-side active salt equivalence card (*Dolo 650 $\leftrightarrow$ Crocin 650*), visual purchase ratio bar, live bill/savings calculator, and multi-drug checklist. |
| **03** | **OCR Scan & Human Verification** | [`scan_review_master.png`](./scan_review_master.png) | [`WIREFRAME_REVIEW_SCAN.md`](./WIREFRAME_REVIEW_SCAN.md) | Color-coded ML Kit bounding boxes, mathematical confidence score badges, cross-cabinet double dosing alert, and on-device privacy banner. |
| **04** | **Daily Dose Intake Timeline** | [`schedule_master.png`](./schedule_master.png) | [`WIREFRAME_REVIEW_SCHEDULE.md`](./WIREFRAME_REVIEW_SCHEDULE.md) | Visual rail node icons (`✓`, `⏰`, `🌙`), 12-day adherence streak, ergonomic `[Snooze]` vs `[Mark Taken]` button layout, and low-stock reorder link. |
| **05** | **Drug Interaction Safety Modal** | [`interaction_alert_master.png`](./interaction_alert_master.png) | [`WIREFRAME_REVIEW_INTERACTION.md`](./WIREFRAME_REVIEW_INTERACTION.md) | Critical clash visualizer (*Aspirin + Warfarin*), physiological mechanism explanation, cardiologist recommendation, and destructive removal action. |

---

## 🎨 Unified Design Tokens

* **Primary Theme:** Deep Emerald Teal (`#0F766E` / `#14B8A6`)
* **Surfaces:** Clean Off-White (`#F8FAFC`) with crisp white elevated cards (`#FFFFFF`, `16px` border radius).
* **Semantic Status Colors:**
  * 🟢 **Safe / High Confidence:** `#10B981`
  * 🟠 **Caution / Suggested Match:** `#F59E0B`
  * 🔴 **Critical Conflict / Low Stock:** `#EF4444`
