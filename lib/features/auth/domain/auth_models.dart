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

class LogisticsOption {
  const LogisticsOption({required this.id, required this.businessName});

  final String id;
  final String businessName;

  factory LogisticsOption.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final businessName = json['business_name'];
    if (id is! String ||
        id.isEmpty ||
        businessName is! String ||
        businessName.trim().isEmpty) {
      throw const ApiContractException('logistics_option');
    }

    return LogisticsOption(id: id, businessName: businessName.trim());
  }
}

class RegistrationUpload {
  const RegistrationUpload({
    required this.path,
    required this.fileName,
    required this.sizeInBytes,
  });

  final String path;
  final String fileName;
  final int sizeInBytes;
}

class CourierRegistrationRequest {
  const CourierRegistrationRequest({
    required this.firstName,
    required this.lastName,
    this.middleName,
    required this.contactNumber,
    required this.sex,
    required this.birthDate,
    required this.email,
    required this.password,
    required this.passwordConfirmation,
    required this.logisticsOrganizationId,
    required this.vehicleType,
    required this.plateNumber,
    required this.addressLine1,
    this.addressLine2,
    required this.barangay,
    required this.cityMunicipality,
    required this.province,
    required this.region,
    required this.postalCode,
    required this.governmentId,
    required this.vehicleRegistration,
  });

  final String firstName;
  final String lastName;
  final String? middleName;
  final String contactNumber;
  final String sex;
  final DateTime birthDate;
  final String email;
  final String password;
  final String passwordConfirmation;
  final String logisticsOrganizationId;
  final String vehicleType;
  final String plateNumber;
  final String addressLine1;
  final String? addressLine2;
  final String barangay;
  final String cityMunicipality;
  final String province;
  final String region;
  final String postalCode;
  final RegistrationUpload governmentId;
  final RegistrationUpload vehicleRegistration;

  Map<String, String> get fields {
    final values = <String, String>{
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'contact_number': contactNumber.trim(),
      'sex': sex,
      'birth_date': _formatDate(birthDate),
      'email': email.trim().toLowerCase(),
      'password': password,
      'password_confirmation': passwordConfirmation,
      'logistics_organization_id': logisticsOrganizationId,
      'vehicle_type': vehicleType,
      'plate_number': plateNumber.trim(),
      'address[address_line_1]': addressLine1.trim(),
      'address[barangay]': barangay.trim(),
      'address[city_municipality]': cityMunicipality.trim(),
      'address[province]': province.trim(),
      'address[region]': region.trim(),
      'address[postal_code]': postalCode.trim(),
    };

    final middleNameValue = middleName?.trim() ?? '';
    if (middleNameValue.isNotEmpty) {
      values['middle_name'] = middleNameValue;
    }

    final addressLine2Value = addressLine2?.trim() ?? '';
    if (addressLine2Value.isNotEmpty) {
      values['address[address_line_2]'] = addressLine2Value;
    }

    return values;
  }

  Map<String, String> get filePaths => <String, String>{
    'government_id': governmentId.path,
    'vehicle_registration': vehicleRegistration.path,
  };
}

class RegistrationResult {
  const RegistrationResult({required this.message, required this.courier});

  final String message;
  final CourierIdentity courier;

  factory RegistrationResult.fromJson(Map<String, dynamic> json) {
    final message = json['message'];
    final courierJson = json['courier'];
    if (message is! String || courierJson is! Map<String, dynamic>) {
      throw const ApiContractException('registration.response');
    }

    return RegistrationResult(
      message: message,
      courier: CourierIdentity.fromJson(courierJson),
    );
  }
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
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
