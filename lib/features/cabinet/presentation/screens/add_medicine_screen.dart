import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../medicine_catalog/data/models/medicine_record.dart';
import '../../../medicine_catalog/data/repositories/medicine_catalog_repository.dart';
import '../../data/models/cabinet_item.dart';
import '../controllers/cabinet_controller.dart';
import '../../../profiles/presentation/controllers/profile_controller.dart';

class AddMedicineScreen extends ConsumerStatefulWidget {
  const AddMedicineScreen({super.key});

  @override
  ConsumerState<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends ConsumerState<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _brandNameController = TextEditingController();
  final _activeSaltController = TextEditingController();
  final _strengthController = TextEditingController();
  final _quantityController = TextEditingController(text: '10');
  final _expiryController = TextEditingController(text: '12/2026');

  String _selectedForm = 'Tablet';
  String _selectedLocation = 'Living Room Drawer';
  List<MedicineRecord> _autocompleteSuggestions = [];
  bool _isSearching = false;

  final List<String> _forms = [
    'Tablet',
    'Capsule',
    'Syrup',
    'Ophthalmic Drop',
    'Ointment',
    'Inhaler',
    'Nasal Spray',
  ];

  final List<String> _quickLocations = [
    'Living Room Drawer',
    'Kitchen Stash',
    'Fridge Door',
    'First Aid Box',
    'Bedside Table',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _brandNameController.dispose();
    _activeSaltController.dispose();
    _strengthController.dispose();
    _quantityController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _autocompleteSuggestions = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final repo = ref.read(medicineCatalogRepositoryProvider);
    final results = await repo.searchMedicines(query.trim());

    setState(() {
      _autocompleteSuggestions = results;
      _isSearching = false;
    });
  }

  void _selectCatalogMedicine(MedicineRecord record) {
    setState(() {
      _brandNameController.text = record.brandName;
      _activeSaltController.text = record.activeSalt;
      _strengthController.text = record.strength;
      _selectedForm = _forms.contains(record.dosageForm) ? record.dosageForm : 'Tablet';
      _autocompleteSuggestions = [];
      _searchController.clear();
    });
  }

  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate()) return;

    final activeProfileId = ref.read(selectedProfileIdProvider) ?? 'profile-primary-self';
    const uuid = Uuid();

    final newItem = CabinetItem(
      id: uuid.v4(),
      brandName: _brandNameController.text.trim(),
      activeSalt: _activeSaltController.text.trim(),
      strength: _strengthController.text.trim(),
      form: _selectedForm,
      quantityRemaining: double.tryParse(_quantityController.text) ?? 10.0,
      printedExpiry: _expiryController.text.trim(),
      storageLocation: _selectedLocation,
      profileId: activeProfileId,
      createdAt: DateTime.now(),
    );

    await ref.read(cabinetNotifierProvider.notifier).addItem(newItem);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${newItem.brandName} to your cabinet!'),
          backgroundColor: AppColors.safe,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add to Cabinet'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // FTS5 Autocomplete Search Box
              const Text(
                'Search Indian Pharmacopoeia Database',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Type brand (e.g. Dolo, Crocin, Pantocid)...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                  suffixIcon: _isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                onChanged: _onSearchChanged,
              ),
              // Autocomplete Dropdown List
              if (_autocompleteSuggestions.isNotEmpty) ...[
                const SizedBox(height: 6),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _autocompleteSuggestions.length.clamp(0, 5),
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _autocompleteSuggestions[index];
                      return ListTile(
                        title: Text(item.brandName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${item.activeSalt} • ${item.strength} (${item.dosageForm})'),
                        trailing: const Icon(Icons.touch_app_outlined, color: AppColors.primary, size: 20),
                        onTap: () => _selectCatalogMedicine(item),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              // Form Fields
              const Text(
                'Medicine Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _brandNameController,
                decoration: const InputDecoration(
                  labelText: 'Brand Trade Name *',
                  hintText: 'e.g. Dolo 650',
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _activeSaltController,
                decoration: const InputDecoration(
                  labelText: 'Active Salt / Composition *',
                  hintText: 'e.g. Paracetamol',
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _strengthController,
                      decoration: const InputDecoration(
                        labelText: 'Strength',
                        hintText: 'e.g. 650mg',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedForm,
                      decoration: const InputDecoration(labelText: 'Form'),
                      items: _forms.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                      onChanged: (val) => setState(() => _selectedForm = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Quantity Remaining *',
                        hintText: 'e.g. 10',
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _expiryController,
                      decoration: const InputDecoration(
                        labelText: 'Printed Expiry *',
                        hintText: 'MM/YYYY',
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Storage Location Selector
              const Text(
                'Physical Storage Location in House',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickLocations.map((loc) {
                  final isSelected = _selectedLocation == loc;
                  return ChoiceChip(
                    label: Text(loc),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedLocation = loc);
                    },
                    selectedColor: AppColors.primarySurface,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Save to Home Cabinet', style: TextStyle(fontSize: 16)),
                  onPressed: _saveMedicine,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
