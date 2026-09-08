class ApiContractException implements Exception {
  const ApiContractException(this.field);

  final String field;

  @override
  String toString() => 'ApiContractException(field: $field)';
}
