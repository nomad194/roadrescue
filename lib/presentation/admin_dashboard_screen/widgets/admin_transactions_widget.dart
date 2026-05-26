import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../theme/app_theme.dart';
import '../../../services/localization_service.dart';

class AdminTransactionsWidget extends StatefulWidget {
  const AdminTransactionsWidget({super.key});

  @override
  State<AdminTransactionsWidget> createState() =>
      _AdminTransactionsWidgetState();
}

class _AdminTransactionsWidgetState extends State<AdminTransactionsWidget> {
  String _filterStatus = 'All';
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _transactions = [];

  List<String> get _filters {
    final l = LocalizationService.instance;
    return [l.t('all'), l.t('done'), 'Pending', 'Refunded'];
  }

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await Supabase.instance.client
          .from('payments')
          .select(
            'id, amount, payment_status, currency, created_at, '
            'customer:customer_id(full_name), '
            'provider:provider_id(full_name), '
            'job:job_request_id(service_type)',
          )
          .order('created_at', ascending: false)
          .limit(100);

      final rows = (response as List).cast<Map<String, dynamic>>();
      _transactions = rows.map(_mapPaymentRow).toList();
    } catch (e) {
      _error = e.toString();
      _transactions = [];
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _mapPaymentRow(Map<String, dynamic> row) {
    final status = _displayStatus(row['payment_status'] as String?);
    final amount = (row['amount'] as num?)?.toDouble() ?? 0;
    final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '');
    final customer = row['customer'] as Map<String, dynamic>?;
    final provider = row['provider'] as Map<String, dynamic>?;
    final job = row['job'] as Map<String, dynamic>?;

    return {
      'id': 'TXN-${((row['id'] as String? ?? '').length >= 8 ? (row['id'] as String).substring(0, 8) : (row['id'] as String? ?? 'N/A')).toUpperCase()}',
      'customer': customer?['full_name'] as String? ?? 'Customer',
      'provider': provider?['full_name'] as String? ?? 'Provider',
      'service': job?['service_type'] as String? ?? 'Service',
      'amount': '\$${amount.toStringAsFixed(2)}',
      'method': 'Card',
      'status': status,
      'date': createdAt != null
          ? DateFormat('MMM d, yyyy').format(createdAt)
          : '',
      'time': createdAt != null
          ? DateFormat('hh:mm a').format(createdAt)
          : '',
    };
  }

  String _displayStatus(String? dbStatus) {
    switch (dbStatus) {
      case 'succeeded':
        return 'Completed';
      case 'refunded':
        return 'Refunded';
      case 'pending':
      case 'failed':
      default:
        return 'Pending';
    }
  }

  List<Map<String, dynamic>> get _filteredTransactions {
    final l = LocalizationService.instance;
    if (_filterStatus == l.t('all') || _filterStatus == 'All') {
      return _transactions;
    }
    return _transactions.where((t) {
      if (_filterStatus == l.t('done')) return t['status'] == 'Completed';
      if (_filterStatus == 'Pending') return t['status'] == 'Pending';
      if (_filterStatus == 'Refunded') return t['status'] == 'Refunded';
      return true;
    }).toList();
  }

  double get _totalRevenue {
    return _transactions
        .where((t) => t['status'] == 'Completed')
        .fold(
          0.0,
          (sum, t) => sum + double.parse(t['amount'].replaceAll('\$', '')),
        );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Completed':
        return AppTheme.success;
      case 'Pending':
        return AppTheme.warning;
      case 'Refunded':
        return AppTheme.error;
      default:
        return AppTheme.muted;
    }
  }

  Color _statusBgColor(String status) {
    switch (status) {
      case 'Completed':
        return AppTheme.successContainer;
      case 'Pending':
        return AppTheme.warningContainer;
      case 'Refunded':
        return AppTheme.errorContainer;
      default:
        return AppTheme.surfaceVariant;
    }
  }

  String _statusLabel(String status) {
    final l = LocalizationService.instance;
    switch (status) {
      case 'Completed':
        return l.t('done');
      case 'Pending':
        return 'Pending';
      case 'Refunded':
        return 'Refunded';
      default:
        return status;
    }
  }

  IconData _methodIcon(String method) {
    switch (method) {
      case 'Card':
        return Icons.credit_card;
      case 'Cash':
        return Icons.payments_outlined;
      case 'Wallet':
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.payment;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    if (_filterStatus == 'All') _filterStatus = l.t('all');

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Column(
        children: [
          Text(
            'Could not load transactions',
            style: GoogleFonts.manrope(color: AppTheme.error),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: _loadTransactions, child: const Text('Retry')),
        ],
      );
    }

    final filtered = _filteredTransactions;
    final completed =
        _transactions.where((t) => t['status'] == 'Completed').length;
    final pending =
        _transactions.where((t) => t['status'] == 'Pending').length;
    final refunded =
        _transactions.where((t) => t['status'] == 'Refunded').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.t('transactions'),
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
        Text(
          '${_transactions.length} total transactions',
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                l.t('revenue'),
                '\$${_totalRevenue.toStringAsFixed(0)}',
                Icons.trending_up,
                AppTheme.primaryContainer,
                AppTheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _summaryCard(
                l.t('done'),
                '$completed',
                Icons.check_circle_outline,
                AppTheme.successContainer,
                AppTheme.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _summaryCard(
                'Pending',
                '$pending',
                Icons.hourglass_empty,
                AppTheme.warningContainer,
                AppTheme.warning,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _summaryCard(
                'Refunded',
                '$refunded',
                Icons.undo,
                AppTheme.errorContainer,
                AppTheme.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filters.map((f) {
              final isSelected = _filterStatus == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _filterStatus = f),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      f,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No transactions yet',
              style: GoogleFonts.manrope(color: AppTheme.muted),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final txn = filtered[index];
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
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _methodIcon(txn['method'] as String),
                            size: 18,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                txn['id'] as String,
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.onSurface,
                                ),
                              ),
                              Text(
                                '${txn['service']} · ${txn['method']}',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: AppTheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              txn['amount'] as String,
                              style: GoogleFonts.manrope(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.onSurface,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _statusBgColor(txn['status'] as String),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                _statusLabel(txn['status'] as String),
                                style: GoogleFonts.manrope(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _statusColor(txn['status'] as String),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 13,
                          color: AppTheme.muted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          txn['customer'] as String,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward,
                          size: 12,
                          color: AppTheme.muted,
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.build_outlined,
                          size: 13,
                          color: AppTheme.muted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            txn['provider'] as String,
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: AppTheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${txn['date']} ${txn['time']}',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _summaryCard(
    String label,
    String value,
    IconData icon,
    Color bgColor,
    Color iconColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: iconColor,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 10,
              color: iconColor.withAlpha(180),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
