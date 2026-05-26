import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../services/localization_service.dart';
import '../../../services/supabase_service.dart';

class AdminPaymentMethodsWidget extends StatefulWidget {
  const AdminPaymentMethodsWidget({super.key});

  @override
  State<AdminPaymentMethodsWidget> createState() => _AdminPaymentMethodsWidgetState();
}

class _AdminPaymentMethodsWidgetState extends State<AdminPaymentMethodsWidget> {
  List<Map<String, dynamic>> _paymentMethods = [];
  bool _isLoading = true;
  bool _isSaving = false;
  RealtimeChannel? _subscription;

  // Provider payment methods
  List<Map<String, dynamic>> _providerPaymentMethods = [];
  final Map<String, TextEditingController> _instructionsControllers = {};
  bool _isLoadingProviderMethods = true;
  bool _isSavingProviderMethods = false;

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
    _loadProviderPaymentMethods();
    _subscribeToChanges();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    // Dispose text controllers
    for (final controller in _instructionsControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _subscribeToChanges() {
    _subscription = Supabase.instance.client
        .channel('payment_methods_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'payment_methods',
          callback: (payload) {
            _loadPaymentMethods();
          },
        )
        .subscribe();
  }

  Future<void> _loadPaymentMethods() async {
    setState(() => _isLoading = true);
    try {
      final methods = await SupabaseService.instance.getPaymentMethods();
      if (mounted) {
        setState(() {
          _paymentMethods = methods;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePaymentMethod(String id, bool enabled) async {
    // Update local state immediately for responsive UI
    setState(() {
      _isSaving = true;
      final index = _paymentMethods.indexWhere((m) => m['id'] == id);
      if (index != -1) {
        _paymentMethods[index]['is_enabled'] = enabled;
      }
    });
    try {
      await SupabaseService.instance.updatePaymentMethod(id, {
        'is_enabled': enabled,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled ? 'Payment method enabled' : 'Payment method disabled',
              style: GoogleFonts.manrope(fontSize: 13),
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      debugPrint('Payment method update error: $e');
      // Revert local state on error
      setState(() {
        final index = _paymentMethods.indexWhere((m) => m['id'] == id);
        if (index != -1) {
          _paymentMethods[index]['is_enabled'] = !enabled;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update payment method',
              style: GoogleFonts.manrope(fontSize: 13),
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── PROVIDER PAYMENT METHODS ──────────────────────────────────────────

  Future<void> _loadProviderPaymentMethods() async {
    setState(() => _isLoadingProviderMethods = true);
    try {
      final methods = await SupabaseService.instance.getAllProviderPaymentMethods();
      if (mounted) {
        setState(() {
          _providerPaymentMethods = methods;
          // Initialize controllers for each method
          for (final method in methods) {
            final id = method['id'] as String;
            final instructions = method['instructions'] as String? ?? '';
            _instructionsControllers[id] = TextEditingController(text: instructions);
          }
          _isLoadingProviderMethods = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading provider payment methods: $e');
      if (mounted) setState(() => _isLoadingProviderMethods = false);
    }
  }

  Future<void> _saveProviderPaymentMethod(String id, bool isEnabled) async {
    setState(() => _isSavingProviderMethods = true);
    try {
      final instructions = _instructionsControllers[id]?.text ?? '';
      await SupabaseService.instance.updateProviderPaymentMethod(
        id,
        isEnabled: isEnabled,
        instructions: instructions,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment method updated',
              style: GoogleFonts.manrope(fontSize: 13),
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      await _loadProviderPaymentMethods();
    } catch (e) {
      debugPrint('Error saving provider payment method: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save: $e',
              style: GoogleFonts.manrope(fontSize: 13),
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingProviderMethods = false);
    }
  }

  void _showAddProviderMethodDialog() {
    final existingTypes = _providerPaymentMethods.map((m) => m['method_type'] as String).toSet();
    final availableTypes = ['bank_transfer', 'cash_deposit', 'online']
        .where((t) => !existingTypes.contains(t))
        .toList();

    if (availableTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All payment method types already exist', style: GoogleFonts.manrope(fontSize: 13)),
          backgroundColor: AppTheme.warning,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Add Payment Method',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: availableTypes.map((type) {
            String label;
            IconData icon;
            switch (type) {
              case 'bank_transfer':
                label = 'Bank Transfer';
                icon = Icons.account_balance;
                break;
              case 'cash_deposit':
                label = 'Cash Deposit';
                icon = Icons.payments_outlined;
                break;
              case 'online':
                label = 'Online Payment';
                icon = Icons.credit_card;
                break;
              default:
                label = type;
                icon = Icons.payment;
            }
            return ListTile(
              leading: Icon(icon, color: AppTheme.primary),
              title: Text(label, style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await Supabase.instance.client.from('provider_payment_methods').insert({
                    'method_type': type,
                    'is_enabled': true,
                    'instructions': '',
                    'created_at': DateTime.now().toIso8601String(),
                    'updated_at': DateTime.now().toIso8601String(),
                  });
                  await _loadProviderPaymentMethods();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$label added', style: GoogleFonts.manrope(fontSize: 13)),
                        backgroundColor: AppTheme.success,
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e', style: GoogleFonts.manrope(fontSize: 13)),
                        backgroundColor: AppTheme.error,
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                  }
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> method) {
    final l = LocalizationService.instance;
    final nameController = TextEditingController(text: method['name'] as String?);
    final descController = TextEditingController(text: method['description'] as String?);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Edit Payment Method',
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
                  labelText: 'Name',
                  filled: true,
                  fillColor: AppTheme.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                style: GoogleFonts.manrope(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  filled: true,
                  fillColor: AppTheme.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                style: GoogleFonts.manrope(fontSize: 14),
                maxLines: 2,
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
            onPressed: () async {
              try {
                await SupabaseService.instance.updatePaymentMethod(
                  method['id'] as String,
                  {
                    'name': nameController.text.trim(),
                    'description': descController.text.trim(),
                  },
                );
                if (mounted) {
                  Navigator.pop(ctx);
                  _loadPaymentMethods();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Payment method updated',
                        style: GoogleFonts.manrope(fontSize: 13),
                      ),
                      backgroundColor: AppTheme.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Failed to update',
                      style: GoogleFonts.manrope(fontSize: 13),
                    ),
                    backgroundColor: AppTheme.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(
              l.t('save'),
              style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIcon(String? iconName) {
    switch (iconName) {
      case 'credit_card':
        return Icons.credit_card;
      case 'payments_outlined':
        return Icons.payments_outlined;
      default:
        return Icons.payment;
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
        Text(
          'Payment Methods',
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
        Text(
          'Configure available payment options for customers',
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryContainer.withAlpha(100),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.primary.withAlpha(50),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Changes here affect which payment options customers see at checkout.',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_isSaving)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ..._paymentMethods.map((method) {
          final isEnabled = method['is_enabled'] as bool? ?? true;
          final isDefault = method['is_default'] as bool? ?? false;
          final code = method['code'] as String? ?? '';
          final name = method['name'] as String? ?? 'Unknown';
          final description = method['description'] as String? ?? '';
          final iconName = method['icon_name'] as String?;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isEnabled ? AppTheme.outlineVariant : AppTheme.outline.withAlpha(50),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: code == 'stripe'
                        ? AppTheme.primaryContainer
                        : AppTheme.successContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getIcon(iconName),
                    size: 24,
                    color: code == 'stripe' ? AppTheme.primary : AppTheme.success,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isEnabled
                                    ? AppTheme.onSurface
                                    : AppTheme.onSurface.withAlpha(128),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isDefault) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withAlpha(20),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'DEFAULT',
                                style: GoogleFonts.manrope(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        description,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: isEnabled
                              ? AppTheme.onSurfaceVariant
                              : AppTheme.onSurfaceVariant.withAlpha(128),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        code.toUpperCase(),
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.muted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _isSaving ? null : () => _showEditDialog(method),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  color: AppTheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Switch(
                  value: isEnabled,
                  onChanged: _isSaving
                      ? null
                      : (v) => _togglePaymentMethod(method['id'] as String, v),
                  activeThumbColor: AppTheme.primary,
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 32),
        // ─── PROVIDER PAYMENT METHODS SECTION ──────────────────────────────────
        Text(
          'Provider Plan Payment Methods',
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
        Text(
          'Configure payment options for provider subscription plans',
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _showAddProviderMethodDialog,
            icon: const Icon(Icons.add, size: 18),
            label: Text(
              'Add Method',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_isLoadingProviderMethods)
          const Center(child: CircularProgressIndicator())
        else
          ..._providerPaymentMethods.map((method) {
            final id = method['id'] as String;
            final methodType = method['method_type'] as String;
            final isEnabled = method['is_enabled'] as bool? ?? true;
            String title;
            IconData icon;
            switch (methodType) {
              case 'bank_transfer':
                title = 'Bank Transfer';
                icon = Icons.account_balance;
                break;
              case 'cash_deposit':
                title = 'Cash Deposit';
                icon = Icons.payments_outlined;
                break;
              case 'online':
                title = 'Online Payment';
                icon = Icons.credit_card;
                break;
              default:
                title = methodType;
                icon = Icons.payment;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isEnabled ? AppTheme.outlineVariant : AppTheme.outline.withAlpha(50),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          icon,
                          size: 24,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isEnabled
                                    ? AppTheme.onSurface
                                    : AppTheme.onSurface.withAlpha(128),
                              ),
                            ),
                            Text(
                              'Manual payment method for providers',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: AppTheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isEnabled,
                        onChanged: _isSavingProviderMethods
                            ? null
                            : (v) => _saveProviderPaymentMethod(id, v),
                        activeThumbColor: AppTheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Instructions shown to providers:',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _instructionsControllers[id],
                    decoration: InputDecoration(
                      hintText: 'Enter payment instructions (bank details, deposit location, etc.)',
                      filled: true,
                      fillColor: AppTheme.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    style: GoogleFonts.manrope(fontSize: 13),
                    maxLines: 5,
                    enabled: !_isSavingProviderMethods,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _isSavingProviderMethods
                          ? null
                          : () => _saveProviderPaymentMethod(id, isEnabled),
                      icon: _isSavingProviderMethods
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(
                        'Save Instructions',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryContainer.withAlpha(100),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.primary.withAlpha(50),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Online payment uses the Stripe gateway configured above. Providers will see these instructions when choosing manual payment methods during plan purchase.',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant.withAlpha(100),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Additional Setup Required',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Stripe requires configuration in your Supabase Edge Functions. Ensure the create-payment-intent function is set up with your Stripe API keys.',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
