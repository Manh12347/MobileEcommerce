int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

String? _toString(dynamic value) {
  final text = value?.toString();
  if (text == null || text.isEmpty || text == 'null') return null;
  return text;
}

class GhnProvince {
  final int provinceId;
  final String provinceName;

  GhnProvince({required this.provinceId, required this.provinceName});

  factory GhnProvince.fromJson(Map<String, dynamic> json) {
    return GhnProvince(
      provinceId: _toInt(json['ProvinceID'] ?? json['province_id']) ?? 0,
      provinceName:
          _toString(json['ProvinceName'] ?? json['province_name']) ?? '',
    );
  }
}

class GhnDistrict {
  final int districtId;
  final int provinceId;
  final String districtName;

  GhnDistrict({
    required this.districtId,
    required this.provinceId,
    required this.districtName,
  });

  factory GhnDistrict.fromJson(Map<String, dynamic> json) {
    return GhnDistrict(
      districtId: _toInt(json['DistrictID'] ?? json['district_id']) ?? 0,
      provinceId: _toInt(json['ProvinceID'] ?? json['province_id']) ?? 0,
      districtName:
          _toString(json['DistrictName'] ?? json['district_name']) ?? '',
    );
  }
}

class GhnWard {
  final String wardCode;
  final int districtId;
  final String wardName;

  GhnWard({
    required this.wardCode,
    required this.districtId,
    required this.wardName,
  });

  factory GhnWard.fromJson(Map<String, dynamic> json) {
    return GhnWard(
      wardCode: _toString(json['WardCode'] ?? json['ward_code']) ?? '',
      districtId: _toInt(json['DistrictID'] ?? json['district_id']) ?? 0,
      wardName: _toString(json['WardName'] ?? json['ward_name']) ?? '',
    );
  }
}
