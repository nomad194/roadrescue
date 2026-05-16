import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../services/localization_service.dart';

class AdminGeoZonesWidget extends StatefulWidget {
  const AdminGeoZonesWidget({super.key});

  @override
  State<AdminGeoZonesWidget> createState() => _AdminGeoZonesWidgetState();
}

class _AdminGeoZonesWidgetState extends State<AdminGeoZonesWidget> {
  String _distanceUnit = 'mi';
  final List<Map<String, dynamic>> _zones = [
    {
      'id': 1,
      'name': 'Downtown Metro',
      'timezone': 'America/New_York',
      'radius': '15',
      'active': true,
      'providers': 32,
    },
    {
      'id': 2,
      'name': 'West Side',
      'timezone': 'America/Chicago',
      'radius': '20',
      'active': true,
      'providers': 18,
    },
    {
      'id': 3,
      'name': 'North Suburbs',
      'timezone': 'America/Los_Angeles',
      'radius': '25',
      'active': false,
      'providers': 11,
    },
    {
      'id': 4,
      'name': 'Airport Zone',
      'timezone': 'America/Denver',
      'radius': '10',
      'active': true,
      'providers': 8,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUnit();
  }

  Future<void> _loadUnit() async {
    try {
      final res = await Supabase.instance.client
          .from('app_settings')
          .select('setting_value')
          .eq('setting_key', 'distance_unit')
          .maybeSingle();
      if (res != null && mounted) {
        setState(() => _distanceUnit = res['setting_value'] ?? 'mi');
      }
    } catch (_) {}
  }

  final List<String> _timezones = [
    'America/New_York',
    'America/Chicago',
    'America/Denver',
    'America/Los_Angeles',
    'America/Phoenix',
    'America/Anchorage',
    'Pacific/Honolulu',
    'Europe/London',
    'Europe/Paris',
    'Asia/Dubai',
    'Asia/Kolkata',
    'Asia/Tokyo',
    'Australia/Sydney',
  ];

  void _showAddEditDialog({Map<String, dynamic>? zone}) {
    final l = LocalizationService.instance;
    final nameController = TextEditingController(text: zone?['name'] ?? '');
    final radiusController = TextEditingController(
      text: zone?['radius'] ?? '',
    );
    String selectedTz = zone?['timezone'] ?? _timezones.first;
    bool isActive = zone?['active'] ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            zone == null ? 'Add Geo Zone' : 'Edit Geo Zone',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppTheme.onSurface,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Zone Name',
                    hintText: 'e.g. Downtown Metro',
                    filled: true,
                    fillColor: AppTheme.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: radiusController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Radius ($_distanceUnit)',
                    hintText: 'e.g. 15',
                    suffixText: _distanceUnit,
                    filled: true,
                    fillColor: AppTheme.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedTz,
                  decoration: InputDecoration(
                    labelText: 'Timezone',
                    filled: true,
                    fillColor: AppTheme.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  dropdownColor: AppTheme.surface,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: AppTheme.onSurface,
                  ),
                  items: _timezones
                      .map(
                        (tz) => DropdownMenuItem(
                          value: tz,
                          child: Text(tz, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedTz = v!),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      l.t('active'),
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Switch(
                      value: isActive,
                      onChanged: (v) => setDialogState(() => isActive = v),
                      activeThumbColor: AppTheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                l.t('cancel'),
                style: GoogleFonts.manrope(color: AppTheme.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                setState(() {
                  if (zone == null) {
                    _zones.add({
                      'id': _zones.length + 1,
                      'name': nameController.text.trim(),
                      'timezone': selectedTz,
                      'radius':
                          radiusController.text.trim().isEmpty ? '10' : radiusController.text.trim(),
                      'active': isActive,
                      'providers': 0,
                    });
                  } else {
                    final idx = _zones.indexWhere((z) => z['id'] == zone['id']);
                    if (idx != -1) {
                      _zones[idx] = {
                        ...zone,
                        'name': nameController.text.trim(),
                        'timezone': selectedTz,
                        'radius':
                            radiusController.text.trim().isEmpty ? zone['radius'] : radiusController.text.trim(),
                        'active': isActive,
                      };
                    }
                  }
                });
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(80, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                l.t('save'),
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.t('geo_zones'),
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  Text(
                    '${_zones.length} zones with timezone assignments',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _showAddEditDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                '${l.t('add_plan').split(' ')[0]} Zone', // Hacky
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(110, 40),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _zones.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final zone = _zones[index];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: zone['active']
                              ? AppTheme.primaryContainer
                              : AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.map_outlined,
                          size: 20,
                          color: zone['active']
                              ? AppTheme.primary
                              : AppTheme.muted,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              zone['name'],
                              style: GoogleFonts.manrope(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.onSurface,
                              ),
                            ),
                            Text(
                              '${zone['providers']} providers · ${zone['radius']} $_distanceUnit',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: AppTheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: zone['active']
                              ? AppTheme.successContainer
                              : AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          zone['active'] ? l.t('active') : 'Inactive',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: zone['active']
                                ? AppTheme.success
                                : AppTheme.muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _showAddEditDialog(zone: zone),
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: AppTheme.primary,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.primaryContainer,
                          minimumSize: const Size(34, 34),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppTheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          zone['timezone'],
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppTheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
