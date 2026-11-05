import '../../features/cabinet/data/models/cabinet_item.dart';
import '../../features/cabinet/data/models/intake_schedule.dart';
import '../../features/cabinet/data/repositories/cabinet_repository.dart';

class DemoDataSeeder {
  DemoDataSeeder._();

  /// Seeds 5 realistic household medicines for instant testing & viva presentations:
  /// 1. Crocin 650 (8 tablets left - Paracetamol 650mg, Living Room Drawer)
  /// 2. Pantocid 40 (14 tablets left - Pantoprazole 40mg, Kitchen Cabinet)
  /// 3. Refresh Tears Eye Drops (Opened 12 days ago - 16 days of safe sterility remaining, Fridge Door)
  /// 4. Augmentin 625 Duo (Day 3 of 5 antibiotic course, Bedside Table)
  /// 5. Ecosprin 75 (25 tablets left - Aspirin 75mg, First Aid Box)
  static Future<void> seedDemoStash(CabinetRepository repository) async {
    final now = DateTime.now();

    final demoItems = [
      CabinetItem(
        id: 'demo-crocin-650',
        brandName: 'Crocin 650',
        activeSalt: 'Paracetamol',
        strength: '650mg',
        form: 'Tablet',
        quantityRemaining: 8.0,
        printedExpiry: '12/2027',
        storageLocation: 'Living Room Drawer',
        symptomTags: ['Fever', 'Headache', 'Body Pain'],
        profileId: 'profile-primary-self',
        createdAt: now.subtract(const Duration(days: 15)),
      ),
      CabinetItem(
        id: 'demo-pantocid-40',
        brandName: 'Pantocid 40',
        activeSalt: 'Pantoprazole',
        strength: '40mg',
        form: 'Tablet',
        quantityRemaining: 14.0,
        printedExpiry: '08/2026',
        storageLocation: 'Kitchen Cabinet',
        symptomTags: ['Acidity', 'Heartburn', 'Gas'],
        profileId: 'profile-primary-self',
        createdAt: now.subtract(const Duration(days: 20)),
      ),
      CabinetItem(
        id: 'demo-refresh-tears',
        brandName: 'Refresh Tears Eye Drops',
        activeSalt: 'Carboxymethylcellulose',
        strength: '0.5%',
        form: 'Ophthalmic Drop',
        quantityRemaining: 1.0,
        printedExpiry: '10/2028',
        isOpened: true,
        openedOnDate: now.subtract(const Duration(days: 12)), // 16 days left of 28-day rule
        storageLocation: 'Fridge Door',
        symptomTags: ['Dry Eyes', 'Eye Strain', 'Redness'],
        profileId: 'profile-primary-self',
        createdAt: now.subtract(const Duration(days: 12)),
      ),
      CabinetItem(
        id: 'demo-augmentin-625',
        brandName: 'Augmentin 625 Duo',
        activeSalt: 'Amoxicillin + Clavulanic Acid',
        strength: '500mg + 125mg',
        form: 'Tablet',
        quantityRemaining: 6.0,
        printedExpiry: '04/2026',
        storageLocation: 'Bedside Table',
        symptomTags: ['Throat Infection', 'Bacterial Fever'],
        profileId: 'profile-primary-self',
        createdAt: now.subtract(const Duration(days: 3)),
      ),
      CabinetItem(
        id: 'demo-ecosprin-75',
        brandName: 'Ecosprin 75',
        activeSalt: 'Aspirin',
        strength: '75mg',
        form: 'Tablet',
        quantityRemaining: 25.0,
        printedExpiry: '03/2027',
        storageLocation: 'First Aid Box',
        symptomTags: ['Cardioprotection', 'Blood Thinner'],
        profileId: 'profile-primary-self',
        createdAt: now.subtract(const Duration(days: 40)),
      ),
    ];

    for (final item in demoItems) {
      await repository.addCabinetItem(item);
    }

    // Seed linked daily intake schedules for Pantocid & Augmentin
    await repository.addSchedule(
      const IntakeSchedule(
        id: 'sched-pantocid-morning',
        cabinetItemId: 'demo-pantocid-40',
        profileId: 'profile-primary-self',
        timeOfDay: '08:00',
        mealRelation: 'BEFORE_FOOD',
        doseAmount: 1.0,
        isAntibiotic: false,
      ),
    );

    await repository.addSchedule(
      const IntakeSchedule(
        id: 'sched-augmentin-course',
        cabinetItemId: 'demo-augmentin-625',
        profileId: 'profile-primary-self',
        timeOfDay: '20:30',
        mealRelation: 'AFTER_FOOD',
        doseAmount: 1.0,
        isAntibiotic: true,
        courseTotalDays: 5,
        courseCurrentDay: 3,
      ),
    );
  }
}
