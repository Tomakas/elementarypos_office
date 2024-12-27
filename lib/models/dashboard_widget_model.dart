// lib/models/dashboard_widget_model.dart

class DashboardWidgetModel {
  final String id;
  final String type; // Např. "summary", "top_products", "hourly_graph", "payment_pie_chart"

  DashboardWidgetModel({required this.id, required this.type});

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
  };

  factory DashboardWidgetModel.fromJson(Map<String, dynamic> json) {
    return DashboardWidgetModel(
      id: json['id'],
      type: json['type'],
    );
  }
}
