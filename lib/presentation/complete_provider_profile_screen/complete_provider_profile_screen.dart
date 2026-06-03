import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:roadrescue_shared/services/localization_service.dart';
import 'package:roadrescue_shared/services/supabase_service.dart';
import 'package:roadrescue_shared/theme/app_theme.dart';

import '../../routes/app_routes.dart';

class CompleteProviderProfileScreen extends StatefulWidget {
  const CompleteProviderProfileScreen({super.key});

  @override
  State<CompleteProviderProfileScreen> createState() =>
      _CompleteProviderProfileScreenState();
}

class _CompleteProviderProfileScreenState
    extends State<CompleteProviderProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _zipController = TextEditingController();
  final _serviceRangeController = TextEditingController(text: '25');

  List<Map<String, dynamic>> _states = [];
  List<Map<String, dynamic>> _cities = [];
  String? _selectedStateId;
  String? _selectedCityId;

  bool _isLoading = false;
  bool _isLoadingGeo = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSocialData();
    _loadGeoData();
  }

  Future<void> _loadSocialData() async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) return;

    final profile = await SupabaseService.instance.getUserProfile(user.id);
    final metadata = user.userMetadata;

    if (mounted) {
      setState(() {
        _nameController.text = profile?['full_name'] as String? ??
            metadata?['full_name'] as String? ??
            '';
        _emailController.text = profile?['email'] as String? ??
            user.email ??
            '';
        _phoneController.text = profile?['phone'] as String? ??
            metadata?['phone'] as String? ??
            '';
        _businessNameController.text =
            profile?['business_name'] as String? ?? '';
        _addressController.text = profile?['address'] as String? ?? '';
        _zipController.text = profile?['zip_code'] as String? ?? '';
        final range = profile?['service_range_miles'] as int?;
        _serviceRangeController.text = (range ?? 25).toString();
        _selectedStateId = profile?['selected_state_id'] as String?;
        _selectedCityId = profile?['selected_city_id'] as String?;
        if (_selectedStateId != null) {
          _loadCitiesForState(_selectedStateId!);
        }
      });
    }
  }

  Future<void> _loadGeoData() async {
    try {
      final states = await SupabaseService.instance.getStates();
      if (mounted) {
        setState(() {
          _states = states;
          _isLoadingGeo = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingGeo = false);
    }
  }

  Future<void> _loadCitiesForState(String stateId) async {
    try {
      final cities = await SupabaseService.instance.getCitiesByState(stateId);
      if (mounted) {
        setState(() {
          _cities = cities;
          // Reset city if current selection is not in new state
          if (_selectedCityId != null &&
              !cities.any((c) => c['id'] == _selectedCityId)) {
            _selectedCityId = null;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cities = []);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    _addressController.dispose();
    _zipController.dispose();
    _serviceRangeController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = SupabaseService.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final serviceRange = int.tryParse(_serviceRangeController.text) ?? 25;

      await SupabaseService.instance.updateProfile(user.id, {
        'full_name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'business_name': _businessNameController.text.trim(),
        'address': _addressController.text.trim(),
        'zip_code': _zipController.text.trim(),
        'service_range_miles': serviceRange,
        if (_selectedStateId != null)
          'selected_state_id': _selectedStateId,
        if (_selectedCityId != null)
          'selected_city_id': _selectedCityId,
        'role': 'provider',
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.providerDocumentsScreen,
          (r) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(maxWidth: isTablet ? 480 : double.infinity),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.t('complete_profile'),
                      style: GoogleFonts.manrope(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.t('complete_profile_desc'),
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_errorMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.errorContainer,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppTheme.error.withAlpha(80),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 16,
                              color: AppTheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  color: AppTheme.error,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildLabel(l.t('full_name')),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Marcus Johnson',
                        prefixIcon: Icon(
                          Icons.person_outline_rounded,
                          size: 20,
                        ),
                        prefixIconColor: AppTheme.muted,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return l.t('full_name_required');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildLabel(l.t('email')),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _emailController,
                      readOnly: true,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.email_outlined, size: 20),
                        prefixIconColor: AppTheme.muted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildLabel(l.t('phone')),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: '+1 (555) 000-0000',
                        prefixIcon: Icon(Icons.phone_outlined, size: 20),
                        prefixIconColor: AppTheme.muted,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return l.t('phone_required');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildLabel(l.t('business_name')),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _businessNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: l.t('business_name'),
                        prefixIcon: const Icon(
                          Icons.business_outlined,
                          size: 20,
                        ),
                        prefixIconColor: AppTheme.muted,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return l.t('business_name_required');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildLabel(l.t('address')),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        hintText: l.t('street_address'),
                        prefixIcon: const Icon(
                          Icons.location_on_outlined,
                          size: 20,
                        ),
                        prefixIconColor: AppTheme.muted,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return l.t('address_required');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildLabel(l.t('zip_code')),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _zipController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: l.t('zip_code'),
                        prefixIcon: const Icon(
                          Icons.local_post_office_outlined,
                          size: 20,
                        ),
                        prefixIconColor: AppTheme.muted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildLabel(l.t('service_range')),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _serviceRangeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '25',
                        prefixIcon: const Icon(
                          Icons.social_distance_outlined,
                          size: 20,
                        ),
                        prefixIconColor: AppTheme.muted,
                        suffixText: l.t('miles'),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return l.t('service_range_required');
                        }
                        final val = int.tryParse(v.trim());
                        if (val == null || val <= 0) {
                          return l.t('service_range_required');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // State dropdown
                    _buildLabel(l.t('state')),
                    const SizedBox(height: 6),
                    _isLoadingGeo
                        ? const SizedBox(
                            height: 48,
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.outlineVariant),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                isExpanded: true,
                                value: _selectedStateId,
                                hint: Text(
                                  l.t('not_set'),
                                  style: GoogleFonts.manrope(
                                    color: AppTheme.muted,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: AppTheme.muted,
                                ),
                                items: [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text(
                                      l.t('not_set'),
                                      style: GoogleFonts.manrope(
                                        color: AppTheme.muted,
                                      ),
                                    ),
                                  ),
                                  ..._states.map((s) {
                                    return DropdownMenuItem<String?>(
                                      value: s['id'] as String,
                                      child: Text(
                                        s['name'] as String? ?? '',
                                        style: GoogleFonts.manrope(),
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedStateId = value;
                                    _selectedCityId = null;
                                    _cities = [];
                                  });
                                  if (value != null) {
                                    _loadCitiesForState(value);
                                  }
                                },
                              ),
                            ),
                          ),
                    const SizedBox(height: 16),
                    // City dropdown
                    _buildLabel(l.t('city')),
                    const SizedBox(height: 6),
                    _selectedStateId == null || _cities.isEmpty
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.outlineVariant),
                            ),
                            child: Text(
                              _selectedStateId == null
                                  ? l.t('select_state_first')
                                  : l.t('no_cities_available'),
                              style: GoogleFonts.manrope(
                                color: AppTheme.muted,
                              ),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.outlineVariant),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                isExpanded: true,
                                value: _selectedCityId,
                                hint: Text(
                                  l.t('not_set'),
                                  style: GoogleFonts.manrope(
                                    color: AppTheme.muted,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: AppTheme.muted,
                                ),
                                items: [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text(
                                      l.t('not_set'),
                                      style: GoogleFonts.manrope(
                                        color: AppTheme.muted,
                                      ),
                                    ),
                                  ),
                                  ..._cities.map((c) {
                                    return DropdownMenuItem<String?>(
                                      value: c['id'] as String,
                                      child: Text(
                                        c['name'] as String? ?? '',
                                        style: GoogleFonts.manrope(),
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedCityId = value;
                                  });
                                },
                              ),
                            ),
                          ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppTheme.primary.withAlpha(100),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 6,
                          shadowColor: AppTheme.primary.withAlpha(120),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                l.t('continue'),
                                style: GoogleFonts.manrope(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.onSurfaceVariant,
      ),
    );
  }
}
