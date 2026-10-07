class ManagerSalesSummary {
  final ManagerSalesTotals totals;
  final List<ManagerSalesDay> days;
  final List<ManagerPaperSalesItem> papers;

  const ManagerSalesSummary({
    required this.totals,
    required this.days,
    required this.papers,
  });

  factory ManagerSalesSummary.fromJson(Map<String, dynamic> json) {
    return ManagerSalesSummary(
      totals: ManagerSalesTotals.fromJson(json['totals'] as Map<String, dynamic>? ?? {}),
      days: (json['days'] as List? ?? [])
          .map((e) => ManagerSalesDay.fromJson(e as Map<String, dynamic>))
          .toList(),
      papers: (json['papers'] as List? ?? [])
          .map((e) => ManagerPaperSalesItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ManagerSalesTotals {
  final int paidOrders;
  final int revenuePaise;
  final int buyers;
  final int averagePaise;
  final int revenueTodayPaise;
  final int revenue7dPaise;
  final int revenue30dPaise;
  final int unpaidOrders;
  final int? conversionPercent;
  final int paidPapers;

  const ManagerSalesTotals({
    required this.paidOrders,
    required this.revenuePaise,
    required this.buyers,
    required this.averagePaise,
    required this.revenueTodayPaise,
    required this.revenue7dPaise,
    required this.revenue30dPaise,
    required this.unpaidOrders,
    this.conversionPercent,
    required this.paidPapers,
  });

  int get revenueRupees => (revenuePaise / 100).round();
  int get revenueTodayRupees => (revenueTodayPaise / 100).round();
  int get revenue7dRupees => (revenue7dPaise / 100).round();
  int get revenue30dRupees => (revenue30dPaise / 100).round();

  factory ManagerSalesTotals.fromJson(Map<String, dynamic> json) {
    return ManagerSalesTotals(
      paidOrders: json['paid_orders'] as int? ?? 0,
      revenuePaise: json['revenue_paise'] as int? ?? 0,
      buyers: json['buyers'] as int? ?? 0,
      averagePaise: json['average_paise'] as int? ?? 0,
      revenueTodayPaise: json['revenue_today_paise'] as int? ?? 0,
      revenue7dPaise: json['revenue_7d_paise'] as int? ?? 0,
      revenue30dPaise: json['revenue_30d_paise'] as int? ?? 0,
      unpaidOrders: json['unpaid_orders'] as int? ?? 0,
      conversionPercent: json['conversion_percent'] as int?,
      paidPapers: json['paid_papers'] as int? ?? 0,
    );
  }
}

class ManagerSalesDay {
  final String date;
  final int orders;
  final int revenuePaise;

  const ManagerSalesDay({
    required this.date,
    required this.orders,
    required this.revenuePaise,
  });

  int get revenueRupees => (revenuePaise / 100).round();

  factory ManagerSalesDay.fromJson(Map<String, dynamic> json) {
    return ManagerSalesDay(
      date: json['date'] as String? ?? '',
      orders: json['orders'] as int? ?? 0,
      revenuePaise: json['revenue_paise'] as int? ?? 0,
    );
  }
}

class ManagerPaperSalesItem {
  final int id;
  final String title;
  final String? courseName;
  final int pricePaise;
  final bool isActive;
  final int sold;
  final int buyers;
  final int revenuePaise;
  final int unpaid;

  const ManagerPaperSalesItem({
    required this.id,
    required this.title,
    this.courseName,
    required this.pricePaise,
    required this.isActive,
    required this.sold,
    required this.buyers,
    required this.revenuePaise,
    required this.unpaid,
  });

  int get priceRupees => (pricePaise / 100).round();
  int get revenueRupees => (revenuePaise / 100).round();

  factory ManagerPaperSalesItem.fromJson(Map<String, dynamic> json) {
    return ManagerPaperSalesItem(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'Untitled Paper',
      courseName: json['course_name'] as String?,
      pricePaise: json['price_paise'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? false,
      sold: json['sold'] as int? ?? 0,
      buyers: json['buyers'] as int? ?? 0,
      revenuePaise: json['revenue_paise'] as int? ?? 0,
      unpaid: json['unpaid'] as int? ?? 0,
    );
  }
}

class ManagerPurchaseOrder {
  final int id;
  final String? studentName;
  final String? studentEmail;
  final String paperTitle;
  final int amountPaise;
  final String status;
  final String? paidAt;
  final String createdAt;

  const ManagerPurchaseOrder({
    required this.id,
    this.studentName,
    this.studentEmail,
    required this.paperTitle,
    required this.amountPaise,
    required this.status,
    this.paidAt,
    required this.createdAt,
  });

  int get amountRupees => (amountPaise / 100).round();

  factory ManagerPurchaseOrder.fromJson(Map<String, dynamic> json) {
    return ManagerPurchaseOrder(
      id: json['id'] as int,
      studentName: json['user'] != null ? json['user']['name'] as String? : null,
      studentEmail: json['user'] != null ? json['user']['email'] as String? : null,
      paperTitle: json['quiz'] != null ? json['quiz']['title'] as String? ?? 'Quiz Paper' : 'Quiz Paper',
      amountPaise: json['amount_paise'] as int? ?? 0,
      status: json['status'] as String? ?? 'created',
      paidAt: json['paid_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}
