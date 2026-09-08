import 'dart:convert';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_contract_exception.dart';
import '../domain/dashboard_models.dart';

abstract interface class DashboardRepository {
  Future<DashboardSnapshot> fetchDashboard();
}

class ApiDashboardRepository implements DashboardRepository {
  ApiDashboardRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  @override
  Future<DashboardSnapshot> fetchDashboard() async {
    final response = await _client.get(
      '/courier/dashboard',
      authenticated: true,
    );

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const ApiContractException('dashboard.response');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ApiContractException('dashboard.response');
    }

    return DashboardSnapshot.fromJson(decoded);
  }
}
