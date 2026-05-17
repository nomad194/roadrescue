import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  List<String> get _filters {
    final l = LocalizationService.instance;
    return [l.t('all'), l.t('done'), 'Pending', 'Refunded'];
  }

  final List<Map<String, dynamic>> _transactions = [
    {
      'id': 'TXN-0041',
      'customer': 'Alex Turner',
      'provider': 'Sarah Williams',
      'service': 'Flat Tire',
      'amount': '\$85.00',
      'method': 'Card',
      'status': 'Completed',
      'date': 'May 2, 2026',
      'time': '09:14 AM',
    },
    {
      'id': 'TXN-0040',
      'customer': 'Priya Sharma',
      'provider': 'David Chen',
      'service': 'Fuel Delivery',
      'amount': '\$45.00',
      'method': 'Cash',
      'status': 'Completed',
      'date': 'May 2, 2026',
      'time': '07:52 AM',
    },
    {
      'id': 'TXN-0039',
      'customer': 'Mike Foster',
      'provider': 'Sarah Williams',
      'service': 'Lockout',
      'amount': '\$120.00',
      'method': 'Card',
      'status': 'Pending',
      'date': 'May 1, 2026',
      'time': '11:30 PM',
    },
    {
      'id': 'TXN-0038',
      'customer': 'Lisa Chen',
      'provider': 'David Chen',
      'service': 'Jump Start',
      'amount': '\$65.00',
      'method': 'Wallet',
      'status': 'Completed',
      'date': 'May 1, 2026',
      'time': '06:45 PM',
    },
    {
      'id': 'TXN-0037',
      'customer': 'James Park',
      'provider': 'Emma Rodriguez',
      'service': 'Towing',
      'amount': '\$210.00',
      'method': 'Card',
      'status': 'Refunded',
      'date': 'Apr 30, 2026',
      'time': '02:20 PM',
    },
    {
      'id': 'TXN-0036',
      'customer': 'Nina Patel',
      'provider': 'Sarah Williams',
      'service': 'Flat Tire',
      'amount': '\$75.00',
      'method': 'Cash',
      'status': 'Completed',
      'date': 'Apr 30, 2026',
      'time': '10:05 AM',
    },
    {
      'id': 'TXN-0035',
      'customer': 'Carlos Ruiz',
      'provider': 'David Chen',
      'service': 'Fuel Delivery',
      'amount': '\$50.00',
      'method': 'Card',
      'status': 'Completed',
      'date': 'Apr 29, 2026',
      'time': '08:33 AM',
    },
  ];

  List<Map<String, dynamic>> get _filteredTransactions {
    final l = LocalizationService.instance;
    if (_filterStatus == l.t('all')) return _transactions;
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
    final filtered = _filteredTransactions;
    if (_filterStatus == 'All') _filterStatus = l.t('all');

    final completed = _transactions
        .where((t) => t['status'] == 'Completed')
        .length;
    final pending = _transactions.where((t) => t['status'] == 'Pending').length;
    final refunded = _transactions
        .where((t) => t['status'] == 'Refunded')
        .length;

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
        // Summary cards
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
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
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
                          _methodIcon(txn['method']),
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
                              txn['id'],
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
                            txn['amount'],
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
                              color: _statusBgColor(txn['status']),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              _statusLabel(txn['status']),
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _statusColor(txn['status']),
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
                        txn['customer'],
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
                          txn['provider'],
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
