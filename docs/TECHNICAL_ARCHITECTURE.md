# MedWise — Technical Architecture & Engineering Specifications

---

## 1. System Architecture Overview

MedWise is built as a **100% Offline-First, Clean Architecture** mobile application. It relies entirely on embedded datasets and local databases, eliminating dependencies on fragile external APIs, cloud outages, or slow mobile data in clinic basements.

```
┌────────────────────────────────────────────────────────┐
│                   PRESENTATION LAYER                   │
│   (Flutter UI Widgets, Screens, Modals & Components)   │
└───────────────────────────▲────────────────────────────┘
                            │ Watches / Dispatches
┌───────────────────────────┴────────────────────────────┐
│                    STATE MANAGEMENT                    │
│   (Riverpod Providers, Notifiers, StateModels)         │
│   - CabinetNotifier   - ChemistCartNotifier            │
│   - ProfileNotifier   - InteractionAlertNotifier       │
└───────────────────────────▲────────────────────────────┘
                            │ Calls Domain Logic
┌───────────────────────────┴────────────────────────────┐
│                      DOMAIN LAYER                      │
│   - FuzzyMatcher Engine (Dice's Coefficient)           │
│   - SaltEquivalence Engine (Composition Mapping)       │
│   - InteractionChecker (Curated Clinical Rules)        │
│   - DoseDepletionCalculator                            │
└───────────────────────────▲────────────────────────────┘
                            │ Interacts via Repositories
┌───────────────────────────┴────────────────────────────┐
│                       DATA LAYER                       │
│  ┌─────────────────────────┐  ┌─────────────────────┐  │
│  │ User Cabinet Database   │  │ Bundled Indian DB   │  │
│  │ (Drift / SQLite / Hive) │  │ (Preloaded SQLite)  │  │
│  └─────────────────────────┘  └─────────────────────┘  │
│  ┌─────────────────────────┐  ┌─────────────────────┐  │
│  │ ML Kit Text Recognition │  │ Local Notification  │  │
│  │ (On-Device OCR)         │  │ Engine & Alarms     │  │
│  └─────────────────────────┘  └─────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

---

## 2. Indian Pharmaceuticals Dataset Strategy

### 2.1 The Data Source
* Sourced from open public Indian pharmaceutical repositories (e.g., Kaggle Indian Medicines Dataset, covering ~10,000+ Indian registered brands).
* Filtered down to the **top ~3,000–5,000 high-frequency medicines** to keep asset size under **12 MB**.

### 2.2 Embedded SQLite Database Schema
Bundled directly in `assets/database/indian_medicines.db` and initialized into the app's read-only cache on first launch:

```sql
-- Main Indian Pharmaceutical Catalog
CREATE TABLE medicines (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    brand_name TEXT NOT NULL,
    active_salt TEXT NOT NULL,
    strength TEXT,
    manufacturer TEXT,
    dosage_form TEXT, -- 'Tablet', 'Capsule', 'Syrup', etc.
    common_symptoms TEXT -- Comma-separated: 'Fever, Pain, Headache'
);

-- Full-Text Search Virtual Table (FTS5) for Instant Autocomplete
CREATE VIRTUAL TABLE medicines_fts USING fts5(
    brand_name,
    active_salt,
    content='medicines',
    content_rowid='id'
);

-- Indexes for sub-millisecond queries
CREATE INDEX idx_brand_name ON medicines(brand_name);
CREATE INDEX idx_active_salt ON medicines(active_salt);
```

---

## 3. User Cabinet Database Schema (Drift / SQLite)

Stored in the app's private documents directory to persist user records:

```sql
-- User's Physical Home Inventory
CREATE TABLE cabinet_items (
    id TEXT PRIMARY KEY, -- UUID
    brand_name TEXT NOT NULL,
    active_salt TEXT NOT NULL,
    strength TEXT NOT NULL,
    form TEXT NOT NULL,
    quantity_remaining REAL NOT NULL, -- e.g., 7.5 tablets
    printed_expiry TEXT NOT NULL,     -- 'MM/YYYY'
    opened_on_date TEXT,             -- ISO8601 for liquids/drops
    is_opened INTEGER DEFAULT 0,
    storage_location TEXT,            -- 'Living Room Drawer'
    symptom_tags TEXT,               -- JSON array of strings
    profile_id TEXT NOT NULL,
    created_at TEXT NOT NULL
);

-- Scheduled Dose Alarms
CREATE TABLE intake_schedules (
    id TEXT PRIMARY KEY,
    cabinet_item_id TEXT NOT NULL,
    profile_id TEXT NOT NULL,
    time_of_day TEXT NOT NULL,        -- '08:00', '20:30'
    meal_relation TEXT NOT NULL,      -- 'BEFORE_FOOD', 'AFTER_FOOD'
    dose_amount REAL NOT NULL,        -- e.g., 1.0
    is_antibiotic INTEGER DEFAULT 0,
    course_total_days INTEGER,
    course_current_day INTEGER,
    FOREIGN KEY(cabinet_item_id) REFERENCES cabinet_items(id) ON DELETE CASCADE
);

-- Family Profiles
CREATE TABLE family_profiles (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    relation TEXT NOT NULL,           -- 'Self', 'Parent', 'Child'
    allergies TEXT,                   -- JSON array of allergic salts
    is_primary INTEGER DEFAULT 0
);
```

---

## 4. OCR & Fuzzy Confidence Scoring Engine

### 4.1 Processing Pipeline
```
[ Blister Pack Photo ]
          │
          ▼
[ Google ML Kit Text Recognition ]
          │
          ▼ Extracted Text Blocks & Lines
[ Regex Date Filter ] ───────► Extracts "EXP: 08/2026" or "08/26"
          │
          ▼ Cleaned Text Lines
[ Fuzzy String Matcher ] (Dice's Coefficient vs. Indian Medicines DB)
          │
          ▼
[ Confidence Scoring & Categorization ]
  ├── Score >= 0.90 ──► Green Indicator (Direct match)
  ├── 0.70 <= Score < 0.90 ──► Amber Indicator (Suggestion)
  └── Score < 0.70 ──► Red Indicator (Manual input required)
```

### 4.2 Mathematical Matching Algorithm
Implemented in pure Dart using Dice's Coefficient (bigram overlap):

$$\text{Similarity}(s_1, s_2) = \frac{2 \times |B(s_1) \cap B(s_2)|}{|B(s_1)| + |B(s_2)|}$$

Where $B(s)$ is the set of character bigrams in string $s$.

```dart
// Implementation snippet in domain/fuzzy_matcher.dart
import 'package:string_similarity/string_similarity.dart';

class MatchCandidate {
  final String rawText;
  final MedicineRecord matchedRecord;
  final double confidenceScore;

  MatchCandidate({
    required this.rawText,
    required this.matchedRecord,
    required this.confidenceScore,
  });

  ConfidenceLevel get level {
    if (confidenceScore >= 0.90) return ConfidenceLevel.high;
    if (confidenceScore >= 0.70) return ConfidenceLevel.medium;
    return ConfidenceLevel.low;
  }
}
```

---

## 5. Curated Drug-Drug Interaction Engine

### 5.1 JSON Structure (`assets/data/drug_interactions.json`)
```json
[
  {
    "salt_a": "aspirin",
    "salt_b": "warfarin",
    "severity": "CRITICAL",
    "effect": "Severe hemorrhage risk due to combined antiplatelet and anticoagulant action.",
    "recommendation": "Avoid concurrent use unless strictly supervised by a cardiologist."
  },
  {
    "salt_a": "ibuprofen",
    "salt_b": "paracetamol",
    "severity": "MODERATE",
    "effect": "Increased risk of renal stress and gastric discomfort with concurrent high doses.",
    "recommendation": "Ensure doses are staggered and do not exceed daily limits."
  },
  {
    "salt_a": "metformin",
    "salt_b": "alcohol",
    "severity": "CRITICAL",
    "effect": "Potentiates risk of severe lactic acidosis.",
    "recommendation": "Avoid alcohol consumption while on metformin."
  }
]
```

### 5.2 Interaction Checking Algorithm
* When a user adds an item or reviews the Chemist Cart, the active salt is cross-referenced with all currently active medicines in the cabinet.
* Because household cabinet size $N \le 20$, the checking complexity is $O(N \times M)$ where $M$ is the curated rules count ($M \approx 60$). The operation completes in **under 2 milliseconds**.

### 5.3 OpenFDA Label Text Integration ("Read More" Reference)
* While critical interaction rules are resolved 100% offline via `drug_interactions.json`, the app provides an optional "Read More Clinical Details" link.
* This queries the openFDA Drug Label endpoint (`https://api.fda.gov/drug/label.json?search=openfda.generic_name:{salt}&limit=1`) to display the FDA's narrative `drug_interactions` text block.
* *Design Decision:* This is treated strictly as an informational deep-dive link; the app's primary interaction safety checks never block or rely on openFDA being online.

---

## 6. Background Scheduling & Platform Channels

### 6.1 Notifications Architecture
* Package: `flutter_local_notifications` combined with `timezone`.
* Uses `AndroidInitializationSettings` with actionable notification categories:
  * Category: `MEDICINE_INTAKE`
  * Action Buttons: `[Mark Taken]`, `[Snooze 15m]`, `[Skip]`

### 6.2 Android 12+ (API 31+) Compliance
* Permissions declared in `AndroidManifest.xml`:
  ```xml
  <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
  <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
  <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
  ```
* Reschedules alarms on device reboot using a BroadcastReceiver.

---

## 7. Dependencies Specification (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter

  # State Management & Architecture
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Local Databases
  sqflite: ^2.3.3+1
  path_provider: ^2.1.3
  path: ^1.9.0

  # Machine Learning & OCR
  google_mlkit_text_recognition: ^0.13.0
  image_picker: ^1.1.2

  # NLP & String Algorithms
  string_similarity: ^2.0.0

  # Notifications & Alarms
  flutter_local_notifications: ^17.2.1
  timezone: ^0.9.3

  # Security & Biometrics
  local_auth: ^2.2.0

  # Utilities & UI
  uuid: ^4.4.0
  intl: ^0.19.0
  flutter_spinkit: ^5.2.1
```
