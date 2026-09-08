import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../core/networking/api_contract_exception.dart';
import '../domain/psgc_address_models.dart';

class PsgcAddressDataSource {
  PsgcAddressDataSource({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const _assetRoot = 'lib/psgc-address-data/data/';
  static const _regionIndexAsset = '${_assetRoot}list-of-all-regions.json';

  final AssetBundle _bundle;
  Future<List<PsgcRegion>>? _regionsFuture;
  final Map<String, Future<PsgcAddressNode>> _regionFutures =
      <String, Future<PsgcAddressNode>>{};

  Future<List<PsgcRegion>> loadRegions() {
    return _regionsFuture ??= _loadRegions();
  }

  Future<PsgcAddressNode> loadRegion(PsgcRegion region) {
    return _regionFutures[region.code] ??= _loadRegion(region);
  }

  Future<List<PsgcRegion>> _loadRegions() async {
    final decoded = await _loadJson(_regionIndexAsset);
    if (decoded is! List) {
      throw const ApiContractException('psgc.region_index');
    }

    final regions = <PsgcRegion>[];
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) {
        throw const ApiContractException('psgc.region_index.item');
      }
      regions.add(PsgcRegion.fromJson(item));
    }
    return List<PsgcRegion>.unmodifiable(regions);
  }

  Future<PsgcAddressNode> _loadRegion(PsgcRegion region) async {
    if (region.assetPath.startsWith('/') ||
        region.assetPath.contains('..') ||
        region.assetPath.contains('\\')) {
      throw const ApiContractException('psgc.region_asset_path');
    }

    final decoded = await _loadJson('$_assetRoot${region.assetPath}');
    if (decoded is! Map<String, dynamic>) {
      throw const ApiContractException('psgc.region_document');
    }
    final regionJson = decoded['region'];
    if (regionJson is! Map<String, dynamic>) {
      throw const ApiContractException('psgc.region_document.region');
    }
    return PsgcAddressNode.fromJson(regionJson);
  }

  Future<Object?> _loadJson(String assetPath) async {
    late final String contents;
    try {
      contents = await _bundle.loadString(assetPath);
    } catch (_) {
      throw const ApiContractException('psgc.asset');
    }
    try {
      return jsonDecode(contents);
    } on FormatException {
      throw const ApiContractException('psgc.json');
    }
  }
}
