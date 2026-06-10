import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:roadrescue_shared/theme/app_theme.dart';
import 'package:roadrescue_shared/services/supabase_service.dart';
import 'package:roadrescue_shared/services/localization_service.dart';
import 'package:roadrescue_shared/services/theme_service.dart';
import 'package:roadrescue_shared/widgets/themed_alert_dialog.dart';

class MyVehicleScreen extends StatefulWidget {
  const MyVehicleScreen({super.key});

  @override
  State<MyVehicleScreen> createState() => _MyVehicleScreenState();
}

class _MyVehicleScreenState extends State<MyVehicleScreen> {
  List<Map<String, dynamic>> _vehicles = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);
    try {
      final vehicles = await SupabaseService.instance.getUserVehicles(userId);
      if (mounted) setState(() => _vehicles = vehicles);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _deleteVehicle(String vehicleId) async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ThemedAlertDialog(role: 'customer',
        backgroundColor: Colors.white.withAlpha(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withAlpha(80)),
        ),
        insetPadding: const EdgeInsets.fromLTRB(40, 40, 40, 90),
        title: Text(
          LocalizationService.instance.t('delete_vehicle_title'),
          style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        content: Text(
          LocalizationService.instance.t('delete_vehicle_confirm'),
          style: GoogleFonts.manrope(fontSize: 14, color: Colors.white.withAlpha(180)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(LocalizationService.instance.t('cancel'), style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white.withAlpha(180))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text(LocalizationService.instance.t('delete'), style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isSaving = true);
      try {
        await SupabaseService.instance.deleteVehicle(vehicleId, userId);
        await _loadVehicles();
        if (mounted) _showSuccess(LocalizationService.instance.t('vehicle_deleted'));
      } catch (e) {
        if (mounted) _showError(LocalizationService.instance.t('vehicle_delete_failed'));
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _setPrimary(String vehicleId) async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;

    setState(() => _isSaving = true);
    try {
      await SupabaseService.instance.setPrimaryVehicle(vehicleId, userId);
      await _loadVehicles();
    } catch (_) {}
    if (mounted) setState(() => _isSaving = false);
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600)), backgroundColor: AppTheme.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), margin: const EdgeInsets.all(16)),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.manrope(fontSize: 13)), backgroundColor: AppTheme.error, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), margin: const EdgeInsets.all(16)),
    );
  }

  void _showAddEditDialog({Map<String, dynamic>? vehicle}) {
    final l = LocalizationService.instance;
    final isEdit = vehicle != null;
    final makeCtrl = TextEditingController(text: vehicle?['make'] ?? '');
    final modelCtrl = TextEditingController(text: vehicle?['model'] ?? '');
    final yearCtrl = TextEditingController(text: vehicle?['year'] ?? '');
    final plateCtrl = TextEditingController(text: vehicle?['plate_number'] ?? '');
    String? selectedColor = vehicle?['color'] as String?;
    String? selectedVehicleType = vehicle?['vehicle_type'] as String? ?? 'car';
    bool isPrimary = vehicle?['is_primary'] == true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => ThemedAlertDialog(role: 'customer',
          backgroundColor: Colors.white.withAlpha(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withAlpha(80)),
          ),
          insetPadding: const EdgeInsets.fromLTRB(20, 40, 20, 90),
          title: Text(l.t(isEdit ? 'edit_vehicle' : 'add_vehicle_title'), style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dialogField(l.t('vehicle_make'), makeCtrl, hint: l.t('vehicle_make_hint')),
                  const SizedBox(height: 12),
                  _dialogField(l.t('vehicle_model'), modelCtrl, hint: l.t('vehicle_model_hint')),
                  const SizedBox(height: 12),
                  _dialogField(l.t('vehicle_year'), yearCtrl, hint: 'e.g. 2023', keyboard: TextInputType.number),
                  const SizedBox(height: 12),
                  _dialogField(l.t('plate_number'), plateCtrl, hint: 'e.g. ABC-1234'),
                  const SizedBox(height: 12),
                  Text(l.t('vehicle_type_label'), style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 6),
                  _buildVehicleTypeDropdown(selectedVehicleType, (v) => setDialogState(() => selectedVehicleType = v)),
                  const SizedBox(height: 12),
                  Text(l.t('vehicle_color'), style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 6),
                  _buildColorDropdown(l, selectedColor, (v) => setDialogState(() => selectedColor = v)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: isPrimary,
                        onChanged: (v) => setDialogState(() => isPrimary = v ?? false),
                        activeColor: AppTheme.primary,
                        checkColor: Colors.white,
                      ),
                      Text(l.t('set_as_primary_vehicle'), style: GoogleFonts.manrope(fontSize: 13, color: Colors.white)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.t('cancel'), style: GoogleFonts.manrope(color: Colors.white.withAlpha(180)))),
            ElevatedButton(
              onPressed: () async {
                if (makeCtrl.text.trim().isEmpty) {
                  _showError(l.t('vehicle_make_required'));
                  return;
                }
                final userId = SupabaseService.instance.currentUser?.id;
                if (userId == null) return;

                Navigator.pop(ctx);
                setState(() => _isSaving = true);
                try {
                  if (isEdit) {
                    await SupabaseService.instance.updateVehicle(
                      vehicleId: vehicle!['id'] as String,
                      userId: userId,
                      make: makeCtrl.text.trim(),
                      model: modelCtrl.text.trim(),
                      color: selectedColor,
                      year: yearCtrl.text.trim(),
                      plateNumber: plateCtrl.text.trim(),
                      vehicleType: selectedVehicleType,
                      isPrimary: isPrimary,
                    );
                  } else {
                    await SupabaseService.instance.createVehicle(
                      userId: userId,
                      make: makeCtrl.text.trim(),
                      model: modelCtrl.text.trim(),
                      color: selectedColor,
                      year: yearCtrl.text.trim(),
                      plateNumber: plateCtrl.text.trim(),
                      vehicleType: selectedVehicleType,
                      isPrimary: _vehicles.isEmpty || isPrimary,
                    );
                  }
                  await _loadVehicles();
                  if (mounted) _showSuccess(l.t(isEdit ? 'vehicle_updated' : 'vehicle_added'));
                } catch (e) {
                  if (mounted) _showError('${l.t('save_failed')} $e');
                } finally {
                  if (mounted) setState(() => _isSaving = false);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: Text(l.t(isEdit ? 'update' : 'add'), style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogField(String label, TextEditingController controller, {String? hint, TextInputType? keyboard}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white.withAlpha(20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withAlpha(80))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withAlpha(80))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.serviceRequestAccent, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            hintStyle: GoogleFonts.manrope(fontSize: 14, color: Colors.white.withAlpha(120)),
          ),
          style: GoogleFonts.manrope(fontSize: 14, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildColorDropdown(LocalizationService l, String? value, ValueChanged<String?> onChanged) {
    const colorKeys = ['black', 'white', 'yellow', 'grey', 'silver', 'blue', 'green', 'red', 'orange', 'brown'];
    return DropdownButtonFormField<String>(
      value: value,
      hint: Text(l.t('select_color'), style: GoogleFonts.manrope(fontSize: 14, color: Colors.white.withAlpha(180))),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withAlpha(20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withAlpha(80))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withAlpha(80))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.serviceRequestAccent, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      style: GoogleFonts.manrope(fontSize: 14, color: Colors.white),
      icon: Icon(Icons.keyboard_arrow_down, color: Colors.white.withAlpha(180)),
      items: colorKeys.map((key) => DropdownMenuItem(value: key, child: Text(l.t(key), style: GoogleFonts.manrope(fontSize: 14, color: Colors.white)))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildVehicleTypeDropdown(String? value, ValueChanged<String?> onChanged) {
    final l = LocalizationService.instance;
    final types = [
      {'key': 'car', 'label': l.t('vehicle_type_car')},
      {'key': 'suv', 'label': l.t('vehicle_type_suv')},
      {'key': 'truck', 'label': l.t('vehicle_type_truck')},
      {'key': 'semi_box_truck', 'label': l.t('vehicle_type_semi_box_truck')},
    ];
    return DropdownButtonFormField<String>(
      value: value,
      hint: Text(l.t('select_type'), style: GoogleFonts.manrope(fontSize: 14, color: Colors.white.withAlpha(180))),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withAlpha(20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withAlpha(80))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withAlpha(80))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.serviceRequestAccent, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      style: GoogleFonts.manrope(fontSize: 14, color: Colors.white),
      icon: Icon(Icons.keyboard_arrow_down, color: Colors.white.withAlpha(180)),
      items: types.map((t) => DropdownMenuItem(value: t['key'], child: Text(t['label']!, style: GoogleFonts.manrope(fontSize: 14, color: Colors.white)))).toList(),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    final ts = ThemeService.instance;
    final screenBg = ts.userScreenBgColor.withAlpha((255 * ts.userScreenBgOpacity).round());
    return Scaffold(
      backgroundColor: screenBg,
      appBar: AppBar(
        backgroundColor: screenBg,
        elevation: 0,
        title: Text(l.t('my_vehicle'), style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_vehicles.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white.withAlpha(20), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withAlpha(80))),
                      child: Column(
                        children: [
                          Icon(Icons.directions_car_outlined, size: 48, color: Colors.white.withAlpha(180)),
                          const SizedBox(height: 12),
                          Text(l.t('no_vehicles_yet'), style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                          const SizedBox(height: 4),
                          Text(l.t('no_vehicles_info'), style: GoogleFonts.manrope(fontSize: 13, color: Colors.white.withAlpha(180))),
                        ],
                      ),
                    )
                  else
                    ..._vehicles.map((v) => _buildVehicleCard(v)),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : () => _showAddEditDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l.t('add_vehicle_title'), style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withAlpha(20), foregroundColor: Colors.white, surfaceTintColor: Colors.transparent, shadowColor: Colors.transparent, elevation: 0, side: BorderSide(color: Colors.white.withAlpha(80)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                  SizedBox(height: MediaQuery.paddingOf(context).bottom + 20),
                ],
              ),
            ),
    );
  }

  Widget _buildVehicleCard(Map<String, dynamic> vehicle) {
    final isPrimary = vehicle['is_primary'] == true;
    final display = SupabaseService.instance.formatVehicleDisplay(vehicle);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isPrimary ? AppTheme.serviceRequestAccent : Colors.white.withAlpha(80), width: isPrimary ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_car_outlined, size: 20, color: isPrimary ? AppTheme.serviceRequestAccent : Colors.white.withAlpha(180)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  display,
                  style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
              if (isPrimary)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppTheme.serviceRequestAccent.withAlpha(30), borderRadius: BorderRadius.circular(6)),
                  child: Text(LocalizationService.instance.t('primary'), style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.serviceRequestAccent)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : () => _showAddEditDialog(vehicle: vehicle),
                  icon: Icon(Icons.edit, size: 16, color: AppTheme.serviceRequestAccent),
                  label: Text(LocalizationService.instance.t('edit'), style: TextStyle(color: AppTheme.serviceRequestAccent)),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.serviceRequestAccent, side: BorderSide(color: AppTheme.serviceRequestAccent.withAlpha(150)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ),
              const SizedBox(width: 8),
              if (!isPrimary)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : () => _setPrimary(vehicle['id'] as String),
                    icon: Icon(Icons.star_outline, size: 16, color: AppTheme.serviceRequestAccent),
                    label: Text(LocalizationService.instance.t('set_primary'), style: TextStyle(color: AppTheme.serviceRequestAccent)),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.serviceRequestAccent, side: BorderSide(color: AppTheme.serviceRequestAccent.withAlpha(150)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                ),
              if (isPrimary) const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : () => _deleteVehicle(vehicle['id'] as String),
                  icon: Icon(Icons.delete_outline, size: 16, color: AppTheme.error),
                  label: Text(LocalizationService.instance.t('delete'), style: TextStyle(color: AppTheme.error)),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error, side: BorderSide(color: AppTheme.error.withAlpha(150)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
