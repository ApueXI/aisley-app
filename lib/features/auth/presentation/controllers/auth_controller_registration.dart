part of 'auth_controller.dart';

extension AuthControllerRegistration on AuthController {
  Future<List<LogisticsOption>> fetchLogisticsOptions({String? search}) {
    return _authRepository.fetchLogisticsOptions(search: search);
  }

  Future<RegistrationResult> register(
    CourierRegistrationRequest request, {
    void Function(void Function() cancel)? onCancel,
  }) {
    return _authRepository.register(request, onCancel: onCancel);
  }
}
