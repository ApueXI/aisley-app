import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/features/auth/data/psgc_address_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'loads the bundled PSGC hierarchy for searchable registration fields',
    () async {
      final source = PsgcAddressDataSource();

      final regions = await source.loadRegions();
      final ncr = regions.singleWhere((region) => region.code == '1300000000');
      final ncrTree = await source.loadRegion(ncr);
      final manila = ncrTree.children.singleWhere(
        (node) => node.name == 'City of Manila',
      );
      final manilaDistrict = manila.children.singleWhere(
        (node) => node.name == 'Tondo I/II',
      );

      expect(regions.length, 18);
      expect(ncr.name, 'National Capital Region (NCR)');
      expect(ncrTree.geographicLevel, 'region');
      expect(manila.geographicLevel, 'city');
      expect(manilaDistrict.geographicLevel, 'sub_municipality');
      expect(manilaDistrict.children, isNotEmpty);
      expect(
        manilaDistrict.children.every(
          (barangay) => barangay.geographicLevel == 'barangay',
        ),
        isTrue,
      );
    },
  );
}
