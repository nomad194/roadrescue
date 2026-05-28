import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/app_constants.dart';
import '../../../theme/app_theme.dart';
import '../../../services/localization_service.dart';
import '../../../services/supabase_service.dart';

class AdminGeoZonesWidget extends StatefulWidget {
  const AdminGeoZonesWidget({super.key});

  @override
  State<AdminGeoZonesWidget> createState() => _AdminGeoZonesWidgetState();
}

class _AdminGeoZonesWidgetState extends State<AdminGeoZonesWidget> {
  List<Map<String, dynamic>> _states = [];
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _geoZones = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final states = await SupabaseService.instance.getStates();
      final cities = await SupabaseService.instance.getAllCities();
      final zones = await SupabaseService.instance.getGeoZones();
      
      if (mounted) {
        setState(() {
          _states = states;
          _cities = cities;
          _geoZones = zones;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading geo data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _createGeoZone() async {
    final l = LocalizationService.instance;
    final nameController = TextEditingController();
    final timezoneController = TextEditingController(text: AppConstants.defaultTimezone);
    
    String? selectedStateId;
    String? selectedCityId;
    
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            'Create Geo Zone',
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Zone Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedStateId,
                  decoration: InputDecoration(
                    labelText: 'State',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: _states.map((s) => DropdownMenuItem(
                    value: s['id'] as String,
                    child: Text(s['name'] as String),
                  )).toList(),
                  onChanged: (val) {
                    setDialogState(() {
                      selectedStateId = val;
                      selectedCityId = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (selectedStateId != null)
                  DropdownButtonFormField<String>(
                    initialValue: selectedCityId,
                    decoration: InputDecoration(
                      labelText: 'City',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: _cities
                      .where((c) => c['state_id'] == selectedStateId)
                      .map((c) => DropdownMenuItem(
                        value: c['id'] as String,
                        child: Text(c['name'] as String),
                      )).toList(),
                    onChanged: (val) {
                      setDialogState(() => selectedCityId = val);
                    },
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: timezoneController,
                  decoration: InputDecoration(
                    labelText: 'Timezone',
                    hintText: 'America/Cancun',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.t('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty || 
                    selectedStateId == null || 
                    selectedCityId == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all fields'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                  return;
                }
                
                Navigator.pop(ctx);
                setState(() => _isSaving = true);
                
                try {
                  await SupabaseService.instance.createGeoZone({
                    'name': nameController.text,
                    'state_id': selectedStateId,
                    'city_id': selectedCityId,
                    'timezone': timezoneController.text,
                    'is_active': true,
                  });
                  
                  await _loadData();
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Geo zone created successfully'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error creating zone: $e'),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isSaving = false);
                }
              },
              child: Text(l.t('create')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleGeoZone(String id, bool isActive) async {
    setState(() => _isSaving = true);
    try {
      await SupabaseService.instance.updateGeoZone(id, {
        'is_active': !isActive,
      });
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating zone: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteGeoZone(String id) async {
    final l = LocalizationService.instance;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('confirm_delete')),
        content: Text(l.t('delete_geo_zone_confirmation')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
            ),
            child: Text(l.t('delete')),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() => _isSaving = true);
    try {
      await SupabaseService.instance.deleteGeoZone(id);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Geo zone deleted'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting zone: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
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
                    'Manage service areas by state and city',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _createGeoZone,
                icon: _isSaving 
                  ? const SizedBox(
                      width: 16, 
                      height: 16, 
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add, size: 18),
                label: const Text('Add Zone'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        
        // States Summary
        if (_states.isNotEmpty) ...[
          Text(
            'Available States',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _states.map((s) => Chip(
              label: Text('${s['name']} (${s['code']})'),
              backgroundColor: AppTheme.primaryContainer,
              labelStyle: GoogleFonts.manrope(
                fontSize: 12,
                color: AppTheme.primary,
              ),
            )).toList(),
          ),
          const SizedBox(height: 20),
        ],
        
        // Cities Summary
        if (_cities.isNotEmpty) ...[
          Text(
            'Cities (${_cities.length} total)',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.outlineVariant),
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ..._cities.take(20).map((c) => Chip(
                  label: Text(c['name'] as String),
                  backgroundColor: AppTheme.surfaceVariant,
                  labelStyle: GoogleFonts.manrope(
                    fontSize: 11,
                    color: AppTheme.onSurface,
                  ),
                  visualDensity: VisualDensity.compact,
                )),
                if (_cities.length > 20)
                  Chip(
                    label: Text('+${_cities.length - 20} more'),
                    backgroundColor: AppTheme.muted.withAlpha(50),
                    labelStyle: GoogleFonts.manrope(
                      fontSize: 11,
                      color: AppTheme.muted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        
        // Geo Zones List
        Text(
          'Geo Zones',
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        
        if (_geoZones.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.outlineVariant),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.map_outlined, size: 48, color: AppTheme.muted),
                  const SizedBox(height: 12),
                  Text(
                    'No geo zones created yet',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: AppTheme.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Click "Add Zone" to create your first geo zone',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _geoZones.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, index) {
              final zone = _geoZones[index];
              final stateName = zone['states']?['name'] ?? 'Unknown';
              final cityName = zone['cities']?['name'] ?? 'Unknown';
              final isActive = zone['is_active'] ?? true;
              
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isActive ? AppTheme.outlineVariant : AppTheme.muted.withAlpha(50)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isActive ? AppTheme.primaryContainer : AppTheme.muted.withAlpha(50),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.location_city,
                        color: isActive ? AppTheme.primary : AppTheme.muted,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            zone['name'] ?? 'Unnamed Zone',
                            style: GoogleFonts.manrope(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isActive ? AppTheme.onSurface : AppTheme.muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$cityName, $stateName',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: AppTheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Timezone: ${zone['timezone'] ?? 'N/A'}',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: AppTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: isActive,
                      onChanged: _isSaving ? null : (v) => _toggleGeoZone(zone['id'], isActive),
                      activeThumbColor: AppTheme.primary,
                    ),
                    IconButton(
                      onPressed: _isSaving ? null : () => _deleteGeoZone(zone['id']),
                      icon: const Icon(Icons.delete_outline),
                      color: AppTheme.error,
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
