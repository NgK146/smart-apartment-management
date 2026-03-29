import '../../core/api_client.dart';

class DashboardOverview {
  final AccountSummary accounts;
  final ApartmentSummary apartments;
  final ComplaintSummary complaints;
  final FinanceSummary finance;
  final List<InteractionPoint> interaction;
  final QuickActions quickActions;

  DashboardOverview({
    required this.accounts,
    required this.apartments,
    required this.complaints,
    required this.finance,
    required this.interaction,
    required this.quickActions,
  });

  factory DashboardOverview.fromJson(Map<String, dynamic> j) => DashboardOverview(
        accounts: AccountSummary.fromJson(Map<String, dynamic>.from(j['accounts'] ?? {})),
        apartments: ApartmentSummary.fromJson(Map<String, dynamic>.from(j['apartments'] ?? {})),
        complaints: ComplaintSummary.fromJson(Map<String, dynamic>.from(j['complaints'] ?? {})),
        finance: FinanceSummary.fromJson(Map<String, dynamic>.from(j['finance'] ?? {})),
        interaction: (j['interaction'] as List<dynamic>? ?? const [])
            .map((e) => InteractionPoint.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        quickActions: QuickActions.fromJson(Map<String, dynamic>.from(j['quickActions'] ?? {})),
      );
}

class AccountSummary {
  final int newThisMonth;
  final int activeThisWeek;
  AccountSummary({required this.newThisMonth, required this.activeThisWeek});
  factory AccountSummary.fromJson(Map<String, dynamic> j) => AccountSummary(
        newThisMonth: j['newThisMonth'] ?? 0,
        activeThisWeek: j['activeThisWeek'] ?? 0,
      );
}

class ApartmentSummary {
  final int occupied;
  final int vacant;
  final int total;
  ApartmentSummary({required this.occupied, required this.vacant, required this.total});
  factory ApartmentSummary.fromJson(Map<String, dynamic> j) => ApartmentSummary(
        occupied: j['occupied'] ?? 0,
        vacant: j['vacant'] ?? 0,
        total: j['total'] ?? 0,
      );
}

class ComplaintSummary {
  final int pending;
  final int overdue;
  ComplaintSummary({required this.pending, required this.overdue});
  factory ComplaintSummary.fromJson(Map<String, dynamic> j) => ComplaintSummary(
        pending: j['pending'] ?? 0,
        overdue: j['overdue'] ?? 0,
      );
}

class FinanceSummary {
  final double collectedThisMonth;
  final double outstandingThisMonth;
  final double overdueAmount;
  final RevenueTrend revenueTrend;

  FinanceSummary({
    required this.collectedThisMonth,
    required this.outstandingThisMonth,
    required this.overdueAmount,
    required this.revenueTrend,
  });

  factory FinanceSummary.fromJson(Map<String, dynamic> j) => FinanceSummary(
        collectedThisMonth: (j['collectedThisMonth'] as num?)?.toDouble() ?? 0,
        outstandingThisMonth: (j['outstandingThisMonth'] as num?)?.toDouble() ?? 0,
        overdueAmount: (j['overdueAmount'] as num?)?.toDouble() ?? 0,
        revenueTrend: RevenueTrend.fromJson(Map<String, dynamic>.from(j['revenueTrend'] ?? {})),
      );
}

class RevenueTrend {
  final double currentMonth;
  final double previousMonth;
  RevenueTrend({required this.currentMonth, required this.previousMonth});
  factory RevenueTrend.fromJson(Map<String, dynamic> j) => RevenueTrend(
        currentMonth: (j['currentMonth'] as num?)?.toDouble() ?? 0,
        previousMonth: (j['previousMonth'] as num?)?.toDouble() ?? 0,
      );
}

class InteractionPoint {
  final String dateLabel;
  final int complaints;
  final int tickets;
  InteractionPoint({required this.dateLabel, required this.complaints, required this.tickets});
  factory InteractionPoint.fromJson(Map<String, dynamic> j) => InteractionPoint(
        dateLabel: j['date']?.toString() ?? '',
        complaints: j['complaints'] ?? 0,
        tickets: j['tickets'] ?? 0,
      );
}

class QuickActions {
  final int overdueComplaints;
  final int pendingApprovals;
  final int unreadSupportTickets;
  QuickActions({
    required this.overdueComplaints,
    required this.pendingApprovals,
    required this.unreadSupportTickets,
  });
  factory QuickActions.fromJson(Map<String, dynamic> j) => QuickActions(
        overdueComplaints: j['overdueComplaints'] ?? 0,
        pendingApprovals: j['pendingApprovals'] ?? 0,
        unreadSupportTickets: j['unreadSupportTickets'] ?? 0,
      );
}

class ReportsService {
  Future<DashboardOverview> overview() async {
    final res = await api.dio.get('/api/reports/overview');
    return DashboardOverview.fromJson(Map<String, dynamic>.from(res.data));
  }
}
