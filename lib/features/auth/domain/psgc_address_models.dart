import '../../../core/networking/api_contract_exception.dart';

class PsgcRegion {
  const PsgcRegion({
    required this.code,
    required this.name,
    required this.assetPath,
  });

  final String code;
  final String name;
  final String assetPath;

  factory PsgcRegion.fromJson(Map<String, dynamic> json) {
    final code = json['psgc_code'];
    final name = json['name'];
    final assetPath = json['file'];
    if (code is! String ||
        code.isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        assetPath is! String ||
        assetPath.isEmpty) {
      throw const ApiContractException('psgc.region');
    }

    return PsgcRegion(code: code, name: name.trim(), assetPath: assetPath);
  }
}

class PsgcAddressNode {
  const PsgcAddressNode({
    required this.code,
    required this.name,
    required this.geographicLevel,
    required this.children,
  });

  final String code;
  final String name;
  final String geographicLevel;
  final List<PsgcAddressNode> children;

  factory PsgcAddressNode.fromJson(Map<String, dynamic> json) {
    final code = json['psgc_code'];
    final name = json['name'];
    final geographicLevel = json['geographic_level'];
    final rawChildren = json['children'];
    if (code is! String ||
        code.isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        geographicLevel is! String ||
        geographicLevel.isEmpty ||
        rawChildren is! List) {
      throw const ApiContractException('psgc.address_node');
    }

    final children = <PsgcAddressNode>[];
    for (final child in rawChildren) {
      if (child is! Map<String, dynamic>) {
        throw const ApiContractException('psgc.address_node.child');
      }
      children.add(PsgcAddressNode.fromJson(child));
    }

    return PsgcAddressNode(
      code: code,
      name: name.trim(),
      geographicLevel: geographicLevel,
      children: List<PsgcAddressNode>.unmodifiable(children),
    );
  }
}
