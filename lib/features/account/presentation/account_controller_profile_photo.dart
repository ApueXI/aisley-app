part of 'account_controller.dart';

extension AccountControllerProfilePhoto on AccountController {
  Future<void> loadProfilePhoto() async {
    final operationEpoch = ++_operationEpoch;
    await _loadProfilePhoto(
      clearMessages: true,
      operationEpoch: operationEpoch,
    );
  }

  Future<bool> _loadProfilePhoto({
    required bool clearMessages,
    required int operationEpoch,
  }) async {
    if (operationEpoch != _operationEpoch) {
      return false;
    }
    final currentAccount = account;
    if (currentAccount == null) {
      profilePhoto = null;
      profilePhotoStatus = ProfilePhotoStatus.idle;
      _clearProfilePhotoMessages();
      _notify();
      return false;
    }

    final photoUrl = currentAccount.profile.profilePhotoUrl;
    if (photoUrl == null || photoUrl.trim().isEmpty) {
      profilePhoto = null;
      profilePhotoStatus = ProfilePhotoStatus.missing;
      _clearProfilePhotoMessages();
      _notify();
      return false;
    }

    if (clearMessages) {
      _clearProfilePhotoMessages();
    } else {
      profilePhotoErrorMessage = null;
      profilePhotoFieldErrors = const <String, List<String>>{};
    }
    profilePhotoStatus = ProfilePhotoStatus.loading;
    _notify();

    try {
      final loadedPhoto = await _accountRepository.fetchProfilePhoto(photoUrl);
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      if (loadedPhoto.bytes.isEmpty) {
        throw const ApiContractException('account.profile_photo.body');
      }
      profilePhoto = loadedPhoto;
      profilePhotoStatus = ProfilePhotoStatus.available;
      _notify();
      return true;
    } on ApiException catch (error) {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      if (error.statusCode == 404) {
        profilePhoto = null;
        profilePhotoStatus = ProfilePhotoStatus.missing;
        profilePhotoErrorMessage = null;
        profilePhotoFieldErrors = const <String, List<String>>{};
        _notify();
        return false;
      }
      await _handleProfilePhotoApiError(error);
    } on TokenStorageException {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      _setProfilePhotoSecureStorageFailure();
    } on ApiContractException {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      _setProfilePhotoRetryableFailure(
        'The profile photo service returned an unexpected response. Please retry.',
      );
    }
    return false;
  }

  Future<bool> uploadProfilePhoto(
    ProfilePhotoSelection selection, {
    void Function(void Function() cancel)? onCancel,
  }) async {
    if (isBusy || account == null) {
      return false;
    }
    if (!account!.security.profilePhotoEditable) {
      profilePhotoStatus = ProfilePhotoStatus.forbidden;
      profilePhotoErrorMessage =
          'Profile photo changes are not available for this account.';
      profilePhotoSuccessMessage = null;
      _notify();
      return false;
    }

    final operationEpoch = ++_operationEpoch;
    profilePhotoStatus = ProfilePhotoStatus.uploading;
    profilePhotoErrorMessage = null;
    profilePhotoSuccessMessage = null;
    profilePhotoFieldErrors = const <String, List<String>>{};
    _notify();

    try {
      final updatedAccount = await _accountRepository.uploadProfilePhoto(
        selection: selection,
        idempotencyKey: _newIdempotencyKey('courier-profile-photo'),
        onCancel: onCancel,
      );
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      account = updatedAccount;
      _onAccountUpdated?.call(updatedAccount);
      _notify();

      final refreshed = await _loadProfilePhoto(
        clearMessages: false,
        operationEpoch: operationEpoch,
      );
      if (refreshed) {
        profilePhotoSuccessMessage = 'Your profile photo was updated.';
        _notify();
        return true;
      }
      if (profilePhotoStatus == ProfilePhotoStatus.missing) {
        _setProfilePhotoRetryableFailure(
          'The upload completed, but the new photo could not be confirmed. Retry the photo refresh.',
        );
      }
      return false;
    } on ApiException catch (error) {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      if (error.isNetworkError &&
          await _reconcileAfterUncertainPhotoUpload(operationEpoch)) {
        return false;
      }
      await _handleProfilePhotoApiError(error);
    } on TokenStorageException {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      _setProfilePhotoSecureStorageFailure();
    } on ApiContractException {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      _setProfilePhotoRetryableFailure(
        'The profile photo service returned an unexpected response. Please retry.',
      );
    }
    return false;
  }

  Future<bool> _reconcileAfterUncertainPhotoUpload(int operationEpoch) async {
    try {
      final refreshedAccount = await _accountRepository.fetchAccount();
      if (operationEpoch != _operationEpoch) {
        return true;
      }
      account = refreshedAccount;
      _onAccountUpdated?.call(refreshedAccount);

      final photoUrl = refreshedAccount.profile.profilePhotoUrl;
      if (photoUrl == null || photoUrl.trim().isEmpty) {
        profilePhoto = null;
        profilePhotoStatus = ProfilePhotoStatus.retryableFailure;
        profilePhotoErrorMessage = 'The upload result was uncertain. We refreshed your account; retry only after reviewing the current photo state.';
        profilePhotoSuccessMessage = null;
        profilePhotoFieldErrors = const <String, List<String>>{};
        _notify();
        return true;
      }

      final confirmed = await _loadProfilePhoto(
        clearMessages: false,
        operationEpoch: operationEpoch,
      );
      if (operationEpoch != _operationEpoch) {
        return true;
      }
      if (confirmed) {
        profilePhotoSuccessMessage = 'Your profile photo was updated.';
        _notify();
        return true;
      }

      if (profilePhotoStatus != ProfilePhotoStatus.signedOut &&
          profilePhotoStatus != ProfilePhotoStatus.forbidden &&
          profilePhotoStatus != ProfilePhotoStatus.secureStorageFailure) {
        _setProfilePhotoRetryableFailure(
          'The upload result was uncertain. We refreshed your account, but could not confirm the private photo. Retry after reviewing the current state.',
        );
      }
      return true;
    } on ApiException catch (error) {
      if (operationEpoch != _operationEpoch) {
        return true;
      }
      await _handleProfilePhotoApiError(error);
      return true;
    } on TokenStorageException {
      if (operationEpoch != _operationEpoch) {
        return true;
      }
      _setProfilePhotoSecureStorageFailure();
      return true;
    } on ApiContractException {
      if (operationEpoch != _operationEpoch) {
        return true;
      }
      _setProfilePhotoRetryableFailure(
        'The upload result was uncertain and could not be reconciled. Refresh your account before retrying.',
      );
      return true;
    }
  }

  Future<bool> deleteProfilePhoto() async {
    if (isBusy || account == null) {
      return false;
    }
    if (!account!.security.profilePhotoEditable) {
      profilePhotoStatus = ProfilePhotoStatus.forbidden;
      profilePhotoErrorMessage =
          'Profile photo changes are not available for this account.';
      profilePhotoSuccessMessage = null;
      _notify();
      return false;
    }

    final operationEpoch = ++_operationEpoch;
    profilePhotoStatus = ProfilePhotoStatus.deleting;
    profilePhotoErrorMessage = null;
    profilePhotoSuccessMessage = null;
    profilePhotoFieldErrors = const <String, List<String>>{};
    _notify();

    try {
      await _accountRepository.deleteProfilePhoto();
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      return await _confirmProfilePhotoDeleted(operationEpoch);
    } on ApiException catch (error) {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      if (error.statusCode == 404) {
        return await _confirmProfilePhotoDeleted(operationEpoch);
      }
      if (error.isNetworkError &&
          await _reconcileAfterUncertainPhotoDelete(operationEpoch)) {
        return false;
      }
      await _handleProfilePhotoApiError(error);
    } on TokenStorageException {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      _setProfilePhotoSecureStorageFailure();
    } on ApiContractException {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      _setProfilePhotoRetryableFailure(
        'The profile photo service returned an unexpected response. Please retry.',
      );
    }
    return false;
  }

  Future<bool> _confirmProfilePhotoDeleted(int operationEpoch) async {
    try {
      final refreshedAccount = await _accountRepository.fetchAccount();
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      account = refreshedAccount;
      _onAccountUpdated?.call(refreshedAccount);
      if (refreshedAccount.profile.profilePhotoUrl == null ||
          refreshedAccount.profile.profilePhotoUrl!.trim().isEmpty) {
        profilePhoto = null;
        profilePhotoStatus = ProfilePhotoStatus.missing;
        profilePhotoErrorMessage = null;
        profilePhotoSuccessMessage = 'Your profile photo was removed.';
        profilePhotoFieldErrors = const <String, List<String>>{};
        _notify();
        return true;
      }

      profilePhotoStatus = profilePhoto == null
          ? ProfilePhotoStatus.retryableFailure
          : ProfilePhotoStatus.available;
      profilePhotoErrorMessage = 'The removal result was uncertain. We refreshed your account; the current photo is still present.';
      profilePhotoSuccessMessage = null;
      _notify();
      return false;
    } on ApiException catch (error) {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      await _handleProfilePhotoApiError(error);
    } on TokenStorageException {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      _setProfilePhotoSecureStorageFailure();
    } on ApiContractException {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      _setProfilePhotoRetryableFailure(
        'The removal result was uncertain. Refresh your account before retrying.',
      );
    }
    return false;
  }

  Future<bool> _reconcileAfterUncertainPhotoDelete(int operationEpoch) async {
    try {
      return await _confirmProfilePhotoDeleted(operationEpoch);
    } on ApiException catch (error) {
      if (operationEpoch != _operationEpoch) {
        return true;
      }
      await _handleProfilePhotoApiError(error);
      return true;
    } on TokenStorageException {
      if (operationEpoch != _operationEpoch) {
        return true;
      }
      _setProfilePhotoSecureStorageFailure();
      return true;
    } on ApiContractException {
      if (operationEpoch != _operationEpoch) {
        return true;
      }
      _setProfilePhotoRetryableFailure(
        'The removal result was uncertain and could not be reconciled. Refresh your account before retrying.',
      );
      return true;
    }
  }
}
