/// Abonelik API modelleri — bkz. backend/app/Http/Controllers/Api/V1/
/// SubscriptionController + PlanController + SubscriptionPaymentRequestController.
library;

class PlanInfo {
  PlanInfo({
    required this.id,
    required this.name,
    required this.slug,
    required this.audience,
    required this.features,
    required this.priceMonthlyMinor,
    required this.priceYearlyMinor,
    required this.yearlySavingsPercent,
    required this.maxUsers,
  });

  factory PlanInfo.fromJson(Map<String, dynamic> json) => PlanInfo(
    id: json['id'] as String,
    name: json['name'] as String,
    slug: json['slug'] as String,
    audience: json['audience'] as String? ?? '',
    features: (json['features'] as List<dynamic>? ?? const [])
        .map((f) => f as String)
        .toList(),
    priceMonthlyMinor: (json['price_monthly_minor'] as num).toInt(),
    priceYearlyMinor: (json['price_yearly_minor'] as num?)?.toInt() ?? 0,
    yearlySavingsPercent:
        (json['yearly_savings_percent'] as num?)?.toInt() ?? 0,
    maxUsers: (json['max_users'] as num?)?.toInt(),
  );

  final String id;
  final String name;
  final String slug;
  final String audience;
  final List<String> features;
  final int priceMonthlyMinor;
  final int priceYearlyMinor;
  final int yearlySavingsPercent;
  final int? maxUsers;
}

class PaymentInfo {
  PaymentInfo({this.iban, this.accountHolder, this.bankName, this.note});

  factory PaymentInfo.fromJson(Map<String, dynamic> json) => PaymentInfo(
    iban: json['iban'] as String?,
    accountHolder: json['account_holder'] as String?,
    bankName: json['bank_name'] as String?,
    note: json['note'] as String?,
  );

  final String? iban;
  final String? accountHolder;
  final String? bankName;
  final String? note;
}

class SubscriptionStatus {
  SubscriptionStatus({
    required this.plan,
    required this.isTrial,
    required this.isActive,
    required this.hasActiveSubscription,
    required this.expiresAt,
    required this.daysRemaining,
    required this.paymentInfo,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return SubscriptionStatus(
      plan: data['plan'] != null
          ? PlanInfo.fromJson(data['plan'] as Map<String, dynamic>)
          : null,
      isTrial: data['is_trial'] as bool? ?? false,
      isActive: data['is_active'] as bool? ?? false,
      hasActiveSubscription: data['has_active_subscription'] as bool? ?? false,
      expiresAt: data['subscription_expires_at'] != null
          ? DateTime.tryParse(data['subscription_expires_at'] as String)
          : null,
      daysRemaining: (data['days_remaining'] as num?)?.toInt(),
      paymentInfo: PaymentInfo.fromJson(
        data['payment_info'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  final PlanInfo? plan;
  final bool isTrial;
  final bool isActive;
  final bool hasActiveSubscription;
  final DateTime? expiresAt;

  /// null = süresiz abonelik (bitiş tarihi yok).
  final int? daysRemaining;
  final PaymentInfo paymentInfo;
}

class PaymentRequestInfo {
  PaymentRequestInfo({
    required this.id,
    required this.status,
    required this.planName,
    required this.approvedPlanName,
    required this.requestedDuration,
    required this.claimedAmountMinor,
    required this.adminNote,
    required this.createdAt,
  });

  factory PaymentRequestInfo.fromJson(Map<String, dynamic> json) =>
      PaymentRequestInfo(
        id: json['id'] as String,
        status: json['status'] as String,
        planName: (json['plan'] as Map<String, dynamic>?)?['name'] as String?,
        approvedPlanName:
            (json['approved_plan'] as Map<String, dynamic>?)?['name']
                as String?,
        requestedDuration: json['requested_duration'] as String?,
        claimedAmountMinor: (json['claimed_amount_minor'] as num?)?.toInt(),
        adminNote: json['admin_note'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );

  final String id;
  final String status;
  final String? planName;
  final String? approvedPlanName;
  final String? requestedDuration;
  final int? claimedAmountMinor;
  final String? adminNote;
  final DateTime? createdAt;
}
