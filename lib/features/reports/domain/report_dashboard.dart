/// Decoded result of the `report_dashboard` RPC
/// (supabase/migrations/0010_features_completion.sql). This RPC returns the
/// whole aggregate — including the full staff_performance array — in one
/// call; it isn't a paginatable table query, so the fields below mirror
/// exactly what the RPC returns rather than a DB table.
class ReportDashboard {
  final num occupancyPercent;
  final int appointments;
  final int completed;
  final int cancelled;
  final int noShow;
  final int revenueMinor;
  final int customers;
  final CustomerMetrics customerMetrics;
  final CampaignMetrics campaignMetrics;
  final List<StaffPerformance> staffPerformance;

  const ReportDashboard({
    required this.occupancyPercent,
    required this.appointments,
    required this.completed,
    required this.cancelled,
    required this.noShow,
    required this.revenueMinor,
    required this.customers,
    required this.customerMetrics,
    required this.campaignMetrics,
    required this.staffPerformance,
  });

  factory ReportDashboard.fromMap(Map<String, dynamic> d) => ReportDashboard(
    occupancyPercent: (d['occupancy_percent'] as num?) ?? 0,
    appointments: (d['appointments'] as num?)?.toInt() ?? 0,
    completed: (d['completed'] as num?)?.toInt() ?? 0,
    cancelled: (d['cancelled'] as num?)?.toInt() ?? 0,
    noShow: (d['no_show'] as num?)?.toInt() ?? 0,
    revenueMinor: (d['revenue_minor'] as num?)?.toInt() ?? 0,
    customers: (d['customers'] as num?)?.toInt() ?? 0,
    customerMetrics: CustomerMetrics.fromMap(
      Map<String, dynamic>.from(d['customer_metrics'] as Map? ?? {}),
    ),
    campaignMetrics: CampaignMetrics.fromMap(
      Map<String, dynamic>.from(d['campaign_metrics'] as Map? ?? {}),
    ),
    staffPerformance: List<Map<String, dynamic>>.from(
      d['staff_performance'] as List? ?? [],
    ).map(StaffPerformance.fromMap).toList(),
  );
}

class CustomerMetrics {
  final int repeatCustomers;
  final int avgSpendMinor;

  const CustomerMetrics({
    required this.repeatCustomers,
    required this.avgSpendMinor,
  });

  factory CustomerMetrics.fromMap(Map<String, dynamic> m) => CustomerMetrics(
    repeatCustomers: (m['repeat_customers'] as num?)?.toInt() ?? 0,
    avgSpendMinor: (m['avg_spend_minor'] as num?)?.toInt() ?? 0,
  );
}

class CampaignMetrics {
  final int campaignsSent;
  final int recipients;
  final int opened;
  final int booked;

  const CampaignMetrics({
    required this.campaignsSent,
    required this.recipients,
    required this.opened,
    required this.booked,
  });

  factory CampaignMetrics.fromMap(Map<String, dynamic> m) => CampaignMetrics(
    campaignsSent: (m['campaigns_sent'] as num?)?.toInt() ?? 0,
    recipients: (m['recipients'] as num?)?.toInt() ?? 0,
    opened: (m['opened'] as num?)?.toInt() ?? 0,
    booked: (m['booked'] as num?)?.toInt() ?? 0,
  );
}

class StaffPerformance {
  final String displayName;
  final int completed;
  final int noShow;
  final int revenueMinor;

  const StaffPerformance({
    required this.displayName,
    required this.completed,
    required this.noShow,
    required this.revenueMinor,
  });

  factory StaffPerformance.fromMap(Map<String, dynamic> m) =>
      StaffPerformance(
        displayName: (m['display_name'] as String?) ?? '',
        completed: (m['completed'] as num?)?.toInt() ?? 0,
        noShow: (m['no_show'] as num?)?.toInt() ?? 0,
        revenueMinor: (m['revenue_minor'] as num?)?.toInt() ?? 0,
      );
}
