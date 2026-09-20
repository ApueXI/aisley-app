import 'dart:typed_data';

import '../../../core/networking/api_contract_exception.dart';
import '../../auth/domain/auth_models.dart';

class ProfilePhotoSelection {
  const ProfilePhotoSelection({
    required this.path,
    required this.fileName,
    required this.bytes,
  });

  /// A readable native path when available; browser uploads use [bytes].
  final String path;
  final String fileName;
  final Uint8List bytes;

  int get sizeInBytes => bytes.length;
}

class ProfilePhotoData {
  const ProfilePhotoData({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}

class CourierAccount {
  const CourierAccount({
    required this.id,
    required this.email,
    required this.role,
    required this.status,
    required this.profile,
    required this.affiliation,
    required this.security,
  });

  final String id;
  final String email;
  final String role;
  final CourierAccountStatus status;
  final AccountProfile profile;
  final AccountAffiliation affiliation;
  final AccountSecurity security;

  factory CourierAccount.fromResponse(Map<String, dynamic> json) {
    final account = json['account'];
    if (account is! Map) {
      throw const ApiContractException('account.response');
    }

    return CourierAccount.fromJson(Map<String, dynamic>.from(account));
  }

  factory CourierAccount.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final email = json['email'];
    final role = json['role'];
    final profile = json['profile'];
    final affiliation = json['affiliation'];
    final security = json['security'];

    if (id is! String ||
        id.isEmpty ||
        email is! String ||
        email.isEmpty ||
        role != 'courier' ||
        profile is! Map ||
        affiliation is! Map ||
        security is! Map) {
      throw const ApiContractException('account.response');
    }

    return CourierAccount(
      id: id,
      email: email,
      role: role as String,
      status: parseCourierAccountStatus(json['status']),
      profile: AccountProfile.fromJson(Map<String, dynamic>.from(profile)),
      affiliation: AccountAffiliation.fromJson(
        Map<String, dynamic>.from(affiliation),
      ),
      security: AccountSecurity.fromJson(Map<String, dynamic>.from(security)),
    );
  }

  CourierIdentity toCourierIdentity() {
    return CourierIdentity(
      id: id,
      email: email,
      role: role,
      status: status,
      profile: CourierProfile(
        firstName: profile.firstName,
        lastName: profile.lastName,
        middleName: profile.middleName,
        age: profile.age,
      ),
      logistics: LogisticsAffiliation(
        status: affiliation.status,
        organizationName: affiliation.organizationName,
        hubName: affiliation.hubName,
      ),
    );
  }
}

class AccountProfile {
  const AccountProfile({
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.contactNumber,
    required this.sex,
    required this.birthDate,
    required this.age,
    this.profilePhotoUrl,
  });

  final String firstName;
  final String? middleName;
  final String lastName;
  final String contactNumber;
  final String sex;
  final String birthDate;
  final int age;
  final String? profilePhotoUrl;

  factory AccountProfile.fromJson(Map<String, dynamic> json) {
    final firstName = json['first_name'];
    final lastName = json['last_name'];
    final contactNumber = json['contact_number'];
    final sex = json['sex'];
    final birthDate = json['birth_date'];
    final age = _parseRequiredInt(json['age'], 'account.profile.age');
    final middleName = _parseNullableString(json['middle_name']);
    final profilePhotoUrl = _parseNullableString(json['profile_photo_url']);

    if (firstName is! String ||
        firstName.trim().isEmpty ||
        lastName is! String ||
        lastName.trim().isEmpty ||
        contactNumber is! String ||
        contactNumber.trim().isEmpty ||
        sex is! String ||
        sex.trim().isEmpty ||
        birthDate is! String ||
        birthDate.trim().isEmpty) {
      throw const ApiContractException('account.profile');
    }

    return AccountProfile(
      firstName: firstName,
      middleName: middleName,
      lastName: lastName,
      contactNumber: contactNumber,
      sex: sex,
      birthDate: birthDate,
      age: age,
      profilePhotoUrl: profilePhotoUrl,
    );
  }
}

class AccountAffiliation {
  const AccountAffiliation({
    required this.status,
    this.organizationName,
    this.hubName,
  });

  final CourierAffiliationStatus status;
  final String? organizationName;
  final String? hubName;

  factory AccountAffiliation.fromJson(Map<String, dynamic> json) {
    return AccountAffiliation(
      status: parseCourierAffiliationStatus(json['status']),
      organizationName: _parseNullableString(json['organization_name']),
      hubName: _parseNullableString(json['hub_name']),
    );
  }
}

class AccountSecurity {
  const AccountSecurity({
    required this.emailEditable,
    required this.profilePhotoEditable,
    required this.passwordChangeRequiresCurrentPassword,
  });

  final bool emailEditable;
  final bool profilePhotoEditable;
  final bool passwordChangeRequiresCurrentPassword;

  factory AccountSecurity.fromJson(Map<String, dynamic> json) {
    final emailEditable = json['email_editable'];
    final profilePhotoEditable = json['profile_photo_editable'];
    final passwordChangeRequiresCurrentPassword =
        json['password_change_requires_current_password'];

    if (emailEditable is! bool ||
        profilePhotoEditable is! bool ||
        passwordChangeRequiresCurrentPassword is! bool) {
      throw const ApiContractException('account.security');
    }

    return AccountSecurity(
      emailEditable: emailEditable,
      profilePhotoEditable: profilePhotoEditable,
      passwordChangeRequiresCurrentPassword:
          passwordChangeRequiresCurrentPassword,
    );
  }
}

int _parseRequiredInt(Object? value, String path) {
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    throw ApiContractException(path);
  }
  return parsed;
}

String? _parseNullableString(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  throw const ApiContractException('account.value');
}
