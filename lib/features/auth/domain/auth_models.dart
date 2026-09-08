import '../../../core/networking/api_contract_exception.dart';

enum CourierAccountStatus { pending, active, rejected, suspended, deactivated }

CourierAccountStatus parseCourierAccountStatus(Object? value) {
  if (value is! String) {
    throw const ApiContractException('courier.status');
  }

  return switch (value) {
    'pending' => CourierAccountStatus.pending,
    'active' => CourierAccountStatus.active,
    'rejected' => CourierAccountStatus.rejected,
    'suspended' => CourierAccountStatus.suspended,
    'deactivated' => CourierAccountStatus.deactivated,
    _ => throw const ApiContractException('courier.status'),
  };
}

enum CourierAffiliationStatus { pending, approved, rejected, revoked }

CourierAffiliationStatus parseCourierAffiliationStatus(Object? value) {
  if (value is! String) {
    throw const ApiContractException('courier.logistics.status');
  }

  return switch (value) {
    'pending' => CourierAffiliationStatus.pending,
    'approved' => CourierAffiliationStatus.approved,
    'rejected' => CourierAffiliationStatus.rejected,
    'revoked' => CourierAffiliationStatus.revoked,
    _ => throw const ApiContractException('courier.logistics.status'),
  };
}

class CourierProfile {
  const CourierProfile({
    required this.firstName,
    required this.lastName,
    this.age,
  });

  final String firstName;
  final String lastName;
  final int? age;

  factory CourierProfile.fromJson(Map<String, dynamic> json) {
    final firstName = json['first_name'];
    final lastName = json['last_name'];
    if (firstName is! String || lastName is! String) {
      throw const ApiContractException('courier.profile');
    }

    final rawAge = json['age'];
    final age = rawAge is int ? rawAge : int.tryParse(rawAge?.toString() ?? '');

    return CourierProfile(firstName: firstName, lastName: lastName, age: age);
  }

  String get displayName => '$firstName $lastName'.trim();
}

class LogisticsAffiliation {
  const LogisticsAffiliation({
    required this.status,
    this.organizationName,
    this.hubName,
  });

  final CourierAffiliationStatus status;
  final String? organizationName;
  final String? hubName;

  factory LogisticsAffiliation.fromJson(Map<String, dynamic> json) {
    return LogisticsAffiliation(
      status: parseCourierAffiliationStatus(json['status']),
      organizationName: _displayName(json['organization']),
      hubName: _displayName(json['hub']),
    );
  }
}

class CourierIdentity {
  const CourierIdentity({
    required this.id,
    required this.email,
    required this.role,
    required this.status,
    this.profile,
    this.logistics,
  });

  final String id;
  final String email;
  final String role;
  final CourierAccountStatus status;
  final CourierProfile? profile;
  final LogisticsAffiliation? logistics;

  factory CourierIdentity.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final email = json['email'];
    final role = json['role'];
    if (id is! String || email is! String || role != 'courier') {
      throw const ApiContractException('courier.identity');
    }

    final profileJson = json['profile'];
    final logisticsJson = json['logistics'];

    return CourierIdentity(
      id: id,
      email: email,
      role: role,
      status: parseCourierAccountStatus(json['status']),
      profile: profileJson is Map<String, dynamic>
          ? CourierProfile.fromJson(profileJson)
          : null,
      logistics: logisticsJson is Map<String, dynamic>
          ? LogisticsAffiliation.fromJson(logisticsJson)
          : null,
    );
  }

  String get displayName => profile?.displayName ?? email;

  String? get organizationName => logistics?.organizationName;

  String? get hubName => logistics?.hubName;
}

String? _displayName(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }

  if (value is Map) {
    final name = value['business_name'] ?? value['name'];
    if (name is String && name.trim().isNotEmpty) {
      return name;
    }
  }

  return null;
}
