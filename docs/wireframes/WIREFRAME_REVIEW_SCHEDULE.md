# Daily Intake Schedule & Dose Timeline — Review & Implementation Specification

* **Master Wireframe:** [`docs/wireframes/schedule_master.png`](./schedule_master.png)
* **Alternative Variant:** [`docs/wireframes/schedule_variant.png`](./schedule_variant.png)
* **Design Standard Selected:** Screen 1 (Screen `ada100d7...`)

---

## 1. Why Screen 1 Was Selected as the Master

1. **Semantic Timeline Node Icons:**
   * Uses distinct icons anchored along the vertical timeline rail:
     * 🟢 **Completed:** `✓` Green checkmark
     * 🟠 **Due Now:** `⏰` Amber clock badge
     * ⚪ **Upcoming:** `🌙` Moon night icon
   * Guides the eye down the chronological schedule effortlessly.
2. **Habit-Building Adherence Streak:**
   * Features a motivating **`🔥 12d streak`** badge next to the 75% daily adherence ring.
   * Encourages patient compliance through positive reinforcement.
3. **Primary vs. Secondary Action Button Hierarchy:**
   * Afternoon slot places **`[ ⏰ Snooze 15m ]`** (secondary outlined) on the left and **`[ ✓ Mark Taken ]`** (primary filled teal) on the right.
   * Aligns with standard mobile UX conventions for thumb-reachable primary actions.
4. **Actionable Low-Stock Reorder Link:**
   * The low-stock warning on Augmentin features an immediate clickable **`Reorder`** action that adds the medication directly to the Chemist shopping list.
5. **Clear Proof of Auto-Depletion:**
   * Slot 1 explicitly documents:  
     `🗄 24 -> 23 tabs in Bedroom Drawer • Auto-logged`  
   * Concretely demonstrates the automatic inventory decrement feature to evaluators.

---

## 2. Micro-Features from Variant 2 to Incorporate

1. **The `[ ⚡ Take Early ]` Action:**
   * For upcoming evening doses, include an optional "Take Early" shortcut so users who finish dinner ahead of time don't have to wait for the alarm to log their dose.
2. **Individual Reminder Bell Toggle:**
   * Provide a quick toggle switch to silence or enable notifications on a per-medicine basis.

---

## 3. Flutter Widget Architecture for this Screen

```dart
Scaffold(
  appBar: MedWiseAppBar(
    title: "Schedule",
    actions: [SearchIconButton(), FamilyProfileAvatar()],
    bottom: DateHeader(
      dateText: "Thursday, 24 Oct",
      subtitle: "Family Health • Daily Intake Schedule",
      isToday: true,
      syncBadge: "Live Sync",
    ),
  ),
  body: SingleChildScrollView(
    padding: EdgeInsets.symmetric(horizontal: 16.0),
    child: Column(
      children: [
        // 1. Weekly Horizontal Calendar Strip
        WeeklyCalendarStrip(
          selectedDate: DateTime(2026, 10, 24),
          completedDates: [DateTime(2026, 10, 21), DateTime(2026, 10, 22), DateTime(2026, 10, 23)],
          onDateSelected: (date) => updateSelectedDay(date),
        ),

        // 2. Adherence Overview Card
        AdherenceSummaryCard(
          dosesTaken: 3,
          totalDoses: 4,
          percentage: 0.75,
          streakDays: 12, // 🔥 12d streak
          nextDoseInfo: "Next: 01:30 PM (Augmentin)",
        ),

        // 3. Chronological Intake Timeline
        SectionHeader(title: "Today's Intake Timeline", badge: "3 Slots Scheduled"),
        TimelineListView(
          slots: [
            // Morning Slot (Completed)
            TimelineSlot(
              time: "08:30 AM • Morning",
              status: SlotStatus.completed(takenAt: "08:32 AM"),
              icon: Icons.check_circle,
              card: DoseCard(
                medicine: "Thyronorm 50mcg",
                genericName: "Levothyroxine Sodium IP",
                instructions: "Take 30 mins before breakfast (Empty Stomach)",
                autoDepleteInfo: "24 -> 23 tabs in Bedroom Drawer",
              ),
            ),

            // Afternoon Slot (Due Now)
            TimelineSlot(
              time: "01:30 PM • Afternoon",
              status: SlotStatus.dueNow,
              icon: Icons.alarm,
              card: DoseCard(
                medicine: "Augmentin 625 Duo",
                genericName: "Amoxicillin & Potassium Clavulanate",
                antibioticProgress: AntibioticProgressBar(currentDay: 3, totalDays: 5),
                stockWarning: LowStockBanner(
                  remainingTabs: 4,
                  onReorderTap: () => addToChemistList("Augmentin 625 Duo"),
                ),
                actions: [
                  OutlinedButton.icon(icon: Icon(Icons.snooze), label: Text("Snooze 15m")),
                  FilledButton.icon(icon: Icon(Icons.check), label: Text("Mark Taken")),
                ],
              ),
            ),

            // Night Slot (Upcoming)
            TimelineSlot(
              time: "09:30 PM • Night",
              status: SlotStatus.upcoming,
              icon: Icons.nightlight_round,
              card: DoseCard(
                medicine: "Pantocid 40mg",
                genericName: "Pantoprazole Gastro-resistant",
                instructions: "Take before sleep / after light dinner",
                cabinetInfo: "18 tablets in Home Cabinet",
                earlyAction: TextButton.icon(icon: Icon(Icons.bolt), label: Text("Take Early")),
              ),
            ),
          ],
        ),
      ],
    ),
  ),
  floatingActionButton: FloatingActionButton(
    child: Icon(Icons.add),
    onPressed: () => openAddScheduleModal(),
  ),
  bottomNavigationBar: MedWiseBottomNavBar(currentIndex: 2), // Schedule tab active
)
```
