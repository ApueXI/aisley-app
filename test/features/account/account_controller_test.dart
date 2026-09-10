import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/account/data/account_repository.dart';
import 'package:aisley_app/features/account/domain/account_models.dart';
import 'package:aisley_app/features/account/presentation/account_controller.dart';

void main() {
  test(
    'keeps the account and exposes field errors on profile validation',
    () async {
      final repository = _FakeAccountRepository()
        ..profileError = const ApiException(
          statusCode: 422,
          code: 'VALIDATION_ERROR',
          message: 'invalid',
          fieldErrors: <String, List<String>>{
            'contact_number': <String>['Enter a valid contact number.'],
          },
        );
      final controller = AccountController(accountRepository: repository);

      await controller.loadAccount();
      final updated = await controller.updateProfile(
        firstName: 'Ana',
        lastName: 'Santos',
        contactNumber: 'bad',
      );

      expect(updated, isFalse);
      expect(controller.status, AccountStatus.validationError);
      expect(controller.fieldError('contact_number'), contains('valid'));
      expect(controller.account, isNotNull);
    },
  );

  test('successful password change requests a fresh session', () async {
    var passwordChanged = false;
    final controller = AccountController(
      accountRepository: _FakeAccountRepository(),
      onPasswordChanged: () async {
        passwordChanged = true;
      },
    );

    await controller.loadAccount();
    final changed = await controller.changePassword(
      currentPassword: 'old-secret',
      password: 'new-secret',
      passwordConfirmation: 'new-secret',
    );

    expect(changed, isTrue);
    expect(passwordChanged, isTrue);
    expect(controller.status, AccountStatus.signedOut);
    expect(controller.account, isNull);
  });

  test('reconciles an uncertain profile save before showing failure', () async {
    final repository = _FakeAccountRepository()
      ..profileError = const ApiException.network('timed out');
    final controller = AccountController(accountRepository: repository);

    await controller.loadAccount();
    final updated = await controller.updateProfile(
      firstName: 'Ana',
      lastName: 'Santos',
      contactNumber: '09171234567',
    );

    expect(updated, isFalse);
    expect(repository.fetchCount, 2);
    expect(controller.status, AccountStatus.retryableFailure);
    expect(controller.errorMessage, contains('uncertain'));
    expect(controller.account, isNotNull);
  });

  test('401 clears the account through the auth boundary', () async {
    ApiException? authFailure;
    final repository = _FakeAccountRepository()
      ..fetchError = const ApiException(
        statusCode: 401,
        code: 'UNAUTHENTICATED',
        message: 'unauthenticated',
      );
    final controller = AccountController(
      accountRepository: repository,
      onAuthFailure: (error) async {
        authFailure = error;
      },
    );

    await controller.loadAccount();

    expect(controller.status, AccountStatus.signedOut);
    expect(authFailure?.statusCode, 401);
    expect(controller.account, isNull);
  });

  test(
    'confirms an uploaded photo only after private refresh succeeds',
    () async {
      final repository = _FakeAccountRepository()
        ..account = CourierAccount.fromJson(_photoAccountJson)
        ..photoUploadResult = CourierAccount.fromJson(_photoAccountJson)
        ..photoData = ProfilePhotoData(
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          contentType: 'image/png',
        );
      final controller = AccountController(accountRepository: repository);

      await controller.loadAccount();
      final uploaded = await controller.uploadProfilePhoto(
        ProfilePhotoSelection(
          path: '/tmp/courier.png',
          fileName: 'courier.png',
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
        ),
      );

      expect(uploaded, isTrue);
      expect(controller.profilePhotoStatus, ProfilePhotoStatus.available);
      expect(controller.profilePhoto?.contentType, 'image/png');
      expect(controller.profilePhotoSuccessMessage, contains('updated'));
    },
  );

  test('reconciles an uncertain photo upload without blind replay', () async {
    final repository = _FakeAccountRepository()
      ..photoUploadError = const ApiException.network('timed out');
    final controller = AccountController(accountRepository: repository);

    await controller.loadAccount();
    final uploaded = await controller.uploadProfilePhoto(
      ProfilePhotoSelection(
        path: '/tmp/courier.png',
        fileName: 'courier.png',
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
      ),
    );

    expect(uploaded, isFalse);
    expect(repository.fetchCount, 2);
    expect(controller.profilePhotoStatus, ProfilePhotoStatus.retryableFailure);
    expect(controller.profilePhotoErrorMessage, contains('uncertain'));
  });

  test(
    'confirms idempotent photo removal from the refreshed account',
    () async {
      final repository = _FakeAccountRepository()
        ..account = CourierAccount.fromJson(_photoAccountJson)
        ..deleteResult = CourierAccount.fromJson(_accountJson);
      final controller = AccountController(accountRepository: repository);

      await controller.loadAccount();
      final removed = await controller.deleteProfilePhoto();

      expect(removed, isTrue);
      expect(controller.profilePhotoStatus, ProfilePhotoStatus.missing);
      expect(controller.profilePhoto, isNull);
      expect(controller.profilePhotoSuccessMessage, contains('removed'));
    },
  );
}

class _FakeAccountRepository implements AccountRepository {
  CourierAccount account = CourierAccount.fromJson(_accountJson);
  Object? fetchError;
  Object? profileError;
  Object? photoUploadError;
  Object? photoError;
  Object? photoDeleteError;
  CourierAccount? photoUploadResult;
  CourierAccount? deleteResult;
  ProfilePhotoData? photoData;
  int fetchCount = 0;

  @override
  Future<CourierAccount> fetchAccount() async {
    fetchCount += 1;
    final error = fetchError;
    if (error != null) {
      throw error;
    }
    return account;
  }

  @override
  Future<CourierAccount> updateProfile({
    required String firstName,
    String? middleName,
    required String lastName,
    required String contactNumber,
    String? idempotencyKey,
  }) async {
    final error = profileError;
    if (error != null) {
      throw error;
    }
    return account;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {}

  @override
  Future<CourierAccount> uploadProfilePhoto({
    required ProfilePhotoSelection selection,
    String? idempotencyKey,
    void Function(void Function() cancel)? onCancel,
  }) async {
    final error = photoUploadError;
    if (error != null) {
      throw error;
    }
    return photoUploadResult ?? account;
  }

  @override
  Future<ProfilePhotoData> fetchProfilePhoto(String profilePhotoUrl) async {
    final error = photoError;
    if (error != null) {
      throw error;
    }
    final loadedPhoto = photoData;
    if (loadedPhoto != null) {
      return loadedPhoto;
    }
    throw const ApiException(
      statusCode: 404,
      code: 'NOT_FOUND',
      message: 'missing',
    );
  }

  @override
  Future<void> deleteProfilePhoto() async {
    final error = photoDeleteError;
    if (error != null) {
      throw error;
    }
    final refreshed = deleteResult;
    if (refreshed != null) {
      account = refreshed;
    }
  }
}

const _accountJson = <String, dynamic>{
  'id': 'courier-1',
  'email': 'courier@example.com',
  'role': 'courier',
  'status': 'active',
  'profile': <String, dynamic>{
    'first_name': 'Ana',
    'middle_name': null,
    'last_name': 'Santos',
    'contact_number': '09171234567',
    'sex': 'female',
    'birth_date': '1999-01-01',
    'age': 27,
    'profile_photo_url': null,
  },
  'affiliation': <String, dynamic>{
    'status': 'approved',
    'organization_name': 'Aisley Express',
    'hub_name': 'Main Hub',
  },
  'security': <String, dynamic>{
    'email_editable': false,
    'profile_photo_editable': true,
    'password_change_requires_current_password': true,
  },
};

const _photoAccountJson = <String, dynamic>{
  'id': 'courier-1',
  'email': 'courier@example.com',
  'role': 'courier',
  'status': 'active',
  'profile': <String, dynamic>{
    'first_name': 'Ana',
    'middle_name': null,
    'last_name': 'Santos',
    'contact_number': '09171234567',
    'sex': 'female',
    'birth_date': '1999-01-01',
    'age': 27,
    'profile_photo_url': '/api/v1/courier/account/profile-photo?v=photo-1',
  },
  'affiliation': <String, dynamic>{
    'status': 'approved',
    'organization_name': 'Aisley Express',
    'hub_name': 'Main Hub',
  },
  'security': <String, dynamic>{
    'email_editable': false,
    'profile_photo_editable': true,
    'password_change_requires_current_password': true,
  },
};
