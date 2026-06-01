class BuildPart {
  const BuildPart({
    required this.name,
    required this.category,
    required this.specifications,
  });

  final String name;
  final String category;
  final Map<String, dynamic> specifications;
}

class BuildCompatibilityResult {
  BuildCompatibilityResult({
    this.valid = true,
    List<String>? errors,
    List<String>? warnings,
    List<String>? info,
  }) : errors = errors ?? <String>[],
       warnings = warnings ?? <String>[],
       info = info ?? <String>[];

  bool valid;
  final List<String> errors;
  final List<String> warnings;
  final List<String> info;
}

BuildCompatibilityResult checkBuildCompatibility(List<BuildPart> build) {
  final result = BuildCompatibilityResult();

  final cpu = _findPart(build, 'CPU');
  final mainboard = _findPart(build, 'Mainboard');
  final ramItems = _findParts(build, 'RAM');
  final gpu = _findPart(build, 'GPU') ?? _findPart(build, 'VGA');
  final pcCase = _findPart(build, 'Case');
  final psu = _findPart(build, 'PSU');
  final cooler = _findPart(build, 'Tan nhiet') ?? _findPart(build, 'Tản nhiệt');
  final storageItems = _findParts(build, 'SSD/HDD');



  // Socket CPU & Mainboard Compatibility check
  String? cpuSocket;
  if (cpu != null) {
    final cpuSpec = cpu.specifications;
    final socketVal = _get(cpuSpec, 'compatibility.socket') ??
        _get(cpuSpec, 'compatibility.cpu_socket');
    cpuSocket = socketVal?.toString();
  }

  String? mbSocket;
  if (mainboard != null) {
    final mbSpec = mainboard.specifications;
    mbSocket = _get(mbSpec, 'compatibility.cpu_socket')?.toString();
  }

  if (cpu != null && mainboard != null && _hasText(cpuSocket) && _hasText(mbSocket) && cpuSocket != mbSocket) {
    _addError(
      result,
      'Socket của CPU ($cpuSocket) không tương thích với socket của Mainboard ($mbSocket).',
    );
  }

  // CPU Generation support check
  if (cpu != null && mainboard != null) {
    final cpuSpec = cpu.specifications;
    final mbSpec = mainboard.specifications;
    final cpuGeneration = _get(cpuSpec, 'compatibility.generation');
    final supportedGenerations = _asList(
      _get(mbSpec, 'compatibility.supported_cpu_generations'),
    );

    if (_hasText(cpuGeneration) &&
        supportedGenerations != null &&
        !supportedGenerations.contains(cpuGeneration)) {
      _addError(
        result,
        'Mainboard (${mainboard.name}) không hỗ trợ CPU thế hệ $cpuGeneration.',
      );
    }
  }

  // RAM Type & Slots check
  if (mainboard != null) {
    final mbSpec = mainboard.specifications;
    var usedRamSlots = 0;
    var totalRamGb = 0;

    for (final ram in ramItems) {
      final ramSpec = ram.specifications;
      final ramType = _get(ramSpec, 'compatibility.memory_type');
      final mbRamType = _get(mbSpec, 'compatibility.memory_type');

      if (_hasText(ramType) && _hasText(mbRamType) && ramType != mbRamType) {
        _addError(
          result,
          'RAM (${ram.name}) là loại $ramType, nhưng Mainboard (${mainboard.name}) yêu cầu loại $mbRamType.',
        );
      }

      usedRamSlots += _toInt(_get(ramSpec, 'compatibility.requires_ram_slots'));
      totalRamGb += _toInt(_get(ramSpec, 'compatibility.total_capacity_gb'));

      final ramFormFactor = _get(ramSpec, 'compatibility.form_factor');
      final mbRamFormFactor = _get(mbSpec, 'compatibility.ram_form_factor');

      if (_hasText(ramFormFactor) &&
          _hasText(mbRamFormFactor) &&
          ramFormFactor != mbRamFormFactor) {
        _addError(
          result,
          'Kích cỡ của RAM (${ram.name}) [$ramFormFactor] không tương thích với loại khe RAM trên Mainboard [$mbRamFormFactor].',
        );
      }
    }

    final mbRamSlots = _toInt(_get(mbSpec, 'compatibility.ram_slots'));
    final mbMaxRam = _toInt(_get(mbSpec, 'compatibility.max_ram_gb'));

    if (mbRamSlots > 0 && usedRamSlots > mbRamSlots) {
      _addError(
        result,
        'Cấu hình yêu cầu $usedRamSlots khe cắm RAM, nhưng Mainboard chỉ có $mbRamSlots khe cắm.',
      );
    }

    if (mbMaxRam > 0 && totalRamGb > mbMaxRam) {
      _addError(
        result,
        'Tổng dung lượng RAM là ${totalRamGb}GB, nhưng Mainboard chỉ hỗ trợ tối đa ${mbMaxRam}GB.',
      );
    }
  }

  // Motherboard Form Factor & Case check
  if (mainboard != null && pcCase != null) {
    final mbSpec = mainboard.specifications;
    final caseSpec = pcCase.specifications;
    final mbFormFactor = _get(mbSpec, 'compatibility.form_factor');
    final caseMbSupport = _asList(
      _get(caseSpec, 'compatibility.motherboard_form_factors'),
    );

    if (_hasText(mbFormFactor) &&
        caseMbSupport != null &&
        !caseMbSupport.contains(mbFormFactor)) {
      _addError(
        result,
        'Vỏ máy tính (${pcCase.name}) không hỗ trợ kích cỡ Mainboard $mbFormFactor.',
      );
    }
  }

  // GPU Expansion Slots check
  if (gpu != null && mainboard != null) {
    final gpuSpec = gpu.specifications;
    final mbSpec = mainboard.specifications;
    final expansionSlots =
        _asList(_get(mbSpec, 'compatibility.expansion_slots')) ?? const [];
    final requiredPcieSlot = _get(gpuSpec, 'compatibility.required_pcie_slot');

    if (_hasText(requiredPcieSlot) &&
        !expansionSlots.contains(requiredPcieSlot)) {
      _addError(
        result,
        'Card đồ họa (${gpu.name}) yêu cầu khe cắm $requiredPcieSlot, nhưng Mainboard không cung cấp khe cắm này.',
      );
    }
  }

  // GPU Length & Case check
  if (gpu != null && pcCase != null) {
    final gpuSpec = gpu.specifications;
    final caseSpec = pcCase.specifications;
    final gpuLength = _toInt(
      _get(gpuSpec, 'compatibility.required_case_gpu_clearance_mm') ??
          _get(gpuSpec, 'physical.length_mm'),
    );
    final maxGpuLength = _toInt(
      _get(caseSpec, 'compatibility.max_gpu_length_mm'),
    );

    if (gpuLength > 0 && maxGpuLength > 0 && gpuLength > maxGpuLength) {
      _addError(
        result,
        'Card đồ họa (${gpu.name}) cần khoảng trống dài ${gpuLength}mm, nhưng vỏ máy tính (${pcCase.name}) chỉ hỗ trợ tối đa ${maxGpuLength}mm.',
      );
    }
  }

  // GPU Wattage and Power connectors check
  if (gpu != null && psu != null) {
    final gpuSpec = gpu.specifications;
    final psuSpec = psu.specifications;
    final gpuRecommendedPsu = _toInt(
      _get(gpuSpec, 'compatibility.recommended_psu_w'),
    );
    final psuWattage = _toInt(
      _get(psuSpec, 'compatibility.wattage_w') ?? _get(psuSpec, 'wattage_w'),
    );

    if (gpuRecommendedPsu > 0 &&
        psuWattage > 0 &&
        psuWattage < gpuRecommendedPsu) {
      _addError(
        result,
        'Card đồ họa (${gpu.name}) khuyến nghị sử dụng nguồn tối thiểu là ${gpuRecommendedPsu}W, nhưng bộ nguồn đã chọn chỉ đạt ${psuWattage}W.',
      );
    }

    _checkPowerConnectors(
      result,
      gpu.name,
      _asConnectorList(_get(gpuSpec, 'compatibility.power_connectors')),
      _asConnectorList(
        _get(psuSpec, 'compatibility.gpu_power_connectors') ??
            _get(psuSpec, 'compatibility.power_connectors'),
      ),
    );
  }

  // CPU Integrated Graphics check
  if (cpu != null && gpu == null) {
    final cpuSpec = cpu.specifications;
    final hasIntegratedGraphics =
        _get(cpuSpec, 'compatibility.integrated_graphics') == true ||
        _get(cpuSpec, 'graphics.integrated') == true;

    if (!hasIntegratedGraphics) {
      _addError(
        result,
        'CPU (${cpu.name}) không có sẵn nhân đồ họa tích hợp, bạn cần chọn thêm card đồ họa rời (GPU/VGA).',
      );
    } else {
      result.info.add('Chưa chọn card đồ họa (VGA), nhưng CPU có sẵn đồ họa tích hợp.');
    }
  }

  // CPU Cooler check
  if (cpu != null) {
    final cpuSpec = cpu.specifications;
    final cpuCoolerIncluded =
        _get(cpuSpec, 'compatibility.cooler_included') == true ||
        _get(cpuSpec, 'cooler_included') == true;

    if (cooler == null && !cpuCoolerIncluded) {
      _addError(
        result,
        'CPU (${cpu.name}) không đi kèm quạt tản nhiệt mặc định, bạn cần chọn thêm tản nhiệt CPU rời.',
      );
    }
  }

  // Cooler Socket & TDP check
  if (cooler != null && cpu != null) {
    final coolerSpec = cooler.specifications;
    final cpuSpec = cpu.specifications;
    final supportedSockets = _asList(
      _get(coolerSpec, 'compatibility.supported_sockets'),
    );

    if (_hasText(cpuSocket) &&
        supportedSockets != null &&
        !supportedSockets.contains(cpuSocket)) {
      _addError(
        result,
        'Tản nhiệt (${cooler.name}) không hỗ trợ loại socket $cpuSocket của CPU.',
      );
    }

    final cpuTdp = _toInt(
      _get(cpuSpec, 'compatibility.tdp_w') ??
          _get(cpuSpec, 'compatibility.base_power_w') ??
          _get(cpuSpec, 'compatibility.processor_base_power_w'),
    );
    final coolerMaxTdp = _toInt(
      _get(coolerSpec, 'compatibility.max_cpu_tdp_w'),
    );

    if (cpuTdp > 0 && coolerMaxTdp > 0 && cpuTdp > coolerMaxTdp) {
      _addError(
        result,
        'Tản nhiệt (${cooler.name}) hỗ trợ tối đa TDP ${coolerMaxTdp}W, nhưng CPU (${cpu.name}) có thể yêu cầu khả năng làm mát tới ${cpuTdp}W.',
      );
    }
  }

  // Cooler physical clearance check
  if (cooler != null && pcCase != null) {
    final coolerSpec = cooler.specifications;
    final coolerType = _get(coolerSpec, 'cooler_type');
    if (coolerType == 'air') {
      _checkAirCoolerCaseClearance(result, cooler, pcCase);
    }
    if (coolerType == 'aio_liquid') {
      _checkAioRadiatorSupport(result, cooler, pcCase);
    }
  }

  // Storage interfaces & drive bays check
  var requiredM2Slots = 0;
  var requiredSataPorts = 0;
  var requiredSataPower = 0;
  var required35Bays = 0;
  var required25Bays = 0;

  for (final drive in storageItems) {
    final driveSpec = drive.specifications;
    if (_get(driveSpec, 'compatibility.requires_m2_slot') == true) {
      requiredM2Slots += 1;
    }

    requiredSataPorts += _toInt(
      _get(driveSpec, 'compatibility.requires_sata_port'),
    );
    requiredSataPower += _toInt(
      _get(driveSpec, 'compatibility.requires_sata_power'),
    );

    final formFactor = _get(driveSpec, 'compatibility.form_factor');
    if (formFactor == '3.5 inch') required35Bays += 1;
    if (formFactor == '2.5 inch') required25Bays += 1;

    if (mainboard != null) {
      final mbSpec = mainboard.specifications;
      final storagePcieGen = _get(
        driveSpec,
        'compatibility.requires_pcie_generation',
      );
      final mbM2Interfaces =
          _asList(_get(mbSpec, 'compatibility.m2_supported_interfaces')) ??
          const [];

      if (_hasText(storagePcieGen) &&
          !mbM2Interfaces.any((value) => '$value'.contains('$storagePcieGen'))) {
        result.warnings.add(
          'Ổ cứng (${drive.name}) sử dụng chuẩn giao tiếp $storagePcieGen, nhưng Mainboard có thể không hỗ trợ tối đa tốc độ này (vẫn hoạt động được nếu có tương thích ngược).',
        );
      }
    }
  }

  if (mainboard != null) {
    final mbSpec = mainboard.specifications;
    final mbM2Slots = _toInt(_get(mbSpec, 'compatibility.m2_slots'));
    final mbSataPorts = _toInt(_get(mbSpec, 'compatibility.sata_ports'));

    if (requiredM2Slots > mbM2Slots) {
      _addError(
        result,
        'Cấu hình yêu cầu $requiredM2Slots khe M.2, nhưng Mainboard chỉ có $mbM2Slots.',
      );
    }

    if (requiredSataPorts > mbSataPorts) {
      _addError(
        result,
        'Cấu hình yêu cầu $requiredSataPorts cổng SATA, nhưng Mainboard chỉ có $mbSataPorts.',
      );
    }
  }

  if (pcCase != null) {
    final caseSpec = pcCase.specifications;
    final caseStorage =
        _asMap(_get(caseSpec, 'compatibility.storage_bays')) ?? const {};
    final case25 = _toInt(caseStorage['sata_2_5']);
    final case35 = _toInt(caseStorage['sata_3_5']);

    if (required25Bays > case25) {
      _addError(
        result,
        'Cấu hình yêu cầu $required25Bays ổ cắm 2.5 inch, nhưng vỏ máy tính chỉ hỗ trợ tối đa $case25 ổ.',
      );
    }

    if (required35Bays > case35) {
      _addError(
        result,
        'Cấu hình yêu cầu $required35Bays ổ cắm 3.5 inch, nhưng vỏ máy tính chỉ hỗ trợ tối đa $case35 ổ.',
      );
    }
  }

  // Mainboard PSU connectors check
  if (mainboard != null && psu != null) {
    final mbSpec = mainboard.specifications;
    final psuSpec = psu.specifications;
    _checkPowerConnectors(
      result,
      mainboard.name,
      _asConnectorList(_get(mbSpec, 'compatibility.required_psu_connectors')),
      _asConnectorList(
        _get(psuSpec, 'compatibility.cpu_power_connectors') ??
            _get(psuSpec, 'compatibility.motherboard_power_connectors') ??
            _get(psuSpec, 'compatibility.power_connectors'),
      ),
    );
  }

  // PSU & Case form factors check
  if (pcCase != null && psu != null) {
    final caseSpec = pcCase.specifications;
    final psuSpec = psu.specifications;
    final casePsuForms = _asList(
      _get(caseSpec, 'compatibility.psu_form_factors'),
    );
    final psuFormFactor =
        _get(psuSpec, 'compatibility.form_factor') ??
        _get(psuSpec, 'form_factor');

    if (_hasText(psuFormFactor) &&
        casePsuForms != null &&
        !casePsuForms.contains(psuFormFactor)) {
      _addError(
        result,
        'Vỏ máy tính (${pcCase.name}) không hỗ trợ kích cỡ nguồn $psuFormFactor.',
      );
    }
  }

  // PSU Sata Power connectors check
  if (psu != null) {
    final psuSpec = psu.specifications;
    final psuSataPower = _toInt(
      _get(psuSpec, 'compatibility.sata_power_connectors'),
    );

    if (requiredSataPower > 0 &&
        psuSataPower > 0 &&
        requiredSataPower > psuSataPower) {
      _addError(
        result,
        'Cấu hình yêu cầu $requiredSataPower đầu nguồn SATA, nhưng bộ nguồn (PSU) chỉ có $psuSataPower đầu.',
      );
    }
  }

  // PSU estimated wattage check
  final estimatedWattage = _estimateBuildWattage(build);
  if (psu != null) {
    final psuSpec = psu.specifications;
    final psuWattage = _toInt(
      _get(psuSpec, 'compatibility.wattage_w') ?? _get(psuSpec, 'wattage_w'),
    );

    if (estimatedWattage > 0 && psuWattage > 0) {
      final recommendedMinimum = (estimatedWattage * 1.3).ceil();

      if (psuWattage < recommendedMinimum) {
        _addError(
          result,
          'Công suất cấu hình ước tính là ${estimatedWattage}W. Khuyến nghị bộ nguồn tối thiểu ${recommendedMinimum}W, nhưng bộ nguồn đã chọn chỉ là ${psuWattage}W.',
        );
      } else {
        result.info.add(
          'Công suất cấu hình ước tính là ${estimatedWattage}W. Bộ nguồn đã chọn ${psuWattage}W hoàn toàn phù hợp.',
        );
      }
    }
  }

  return result;
}

BuildPart? _findPart(List<BuildPart> build, String categoryName) {
  for (final item in build) {
    if (_normalize(item.category) == _normalize(categoryName)) {
      return item;
    }
  }
  return null;
}

List<BuildPart> _findParts(List<BuildPart> build, String categoryName) {
  return build
      .where((item) => _normalize(item.category) == _normalize(categoryName))
      .toList();
}

String normalizeBuildCategory(String value) => _normalize(value);

String _normalize(Object? value) {
  const marks =
      'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  const replacements =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  var text = '$value'.toLowerCase();
  for (var i = 0; i < marks.length; i++) {
    text = text.replaceAll(marks[i], replacements[i]);
  }
  return text.trim();
}

void _requirePart(BuildCompatibilityResult result, Object? part, String name) {
  if (part == null) {
    _addError(result, 'Thiếu $name.');
  }
}

void _addError(BuildCompatibilityResult result, String message) {
  result.valid = false;
  result.errors.add(message);
}

Object? _get(Map<String, dynamic> obj, String path) {
  Object? current = obj;
  for (final key in path.split('.')) {
    if (current is! Map) return null;
    current = current[key];
  }
  return current;
}

bool _hasText(Object? value) => value != null && '$value'.trim().isNotEmpty;

int _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}

List<dynamic>? _asList(Object? value) {
  return value is List ? value : null;
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, mapValue) => MapEntry('$key', mapValue));
  }
  return null;
}

List<Map<String, dynamic>> _asConnectorList(Object? value) {
  final list = _asList(value);
  if (list == null) return const [];
  return list
      .whereType<Map>()
      .map((item) => item.map((key, mapValue) => MapEntry('$key', mapValue)))
      .toList();
}

void _checkAirCoolerCaseClearance(
  BuildCompatibilityResult result,
  BuildPart cooler,
  BuildPart pcCase,
) {
  final coolerHeight = _toInt(
    _get(cooler.specifications, 'physical.height_mm') ??
        _get(
          cooler.specifications,
          'compatibility.requires_case_cpu_cooler_clearance_mm',
        ),
  );
  final caseClearance = _toInt(
    _get(pcCase.specifications, 'compatibility.max_cpu_cooler_height_mm'),
  );

  if (coolerHeight > 0 && caseClearance > 0 && coolerHeight > caseClearance) {
    _addError(
      result,
      'Tản nhiệt (${cooler.name}) cao ${coolerHeight}mm, nhưng vỏ máy tính (${pcCase.name}) chỉ hỗ trợ chiều cao tản nhiệt tối đa là ${caseClearance}mm.',
    );
  }
}

void _checkAioRadiatorSupport(
  BuildCompatibilityResult result,
  BuildPart cooler,
  BuildPart pcCase,
) {
  final radiatorSize = _toInt(
    _get(cooler.specifications, 'compatibility.radiator_size_mm') ??
        _get(cooler.specifications, 'physical.radiator_size_mm'),
  );
  final allowedPositions =
      _asList(
        _get(cooler.specifications, 'compatibility.allowed_mount_positions'),
      ) ??
      const ['front', 'top', 'rear'];
  final caseRadiatorSupport =
      _asMap(
        _get(pcCase.specifications, 'compatibility.radiator_support_mm'),
      ) ??
      const {};

  final compatiblePosition = allowedPositions.any((position) {
    final supportedSizes = _asList(caseRadiatorSupport[position]);
    return supportedSizes != null && supportedSizes.contains(radiatorSize);
  });

  if (radiatorSize > 0 && !compatiblePosition) {
    _addError(
      result,
      'Vỏ máy tính (${pcCase.name}) không hỗ trợ két tản nhiệt nước kích cỡ ${radiatorSize}mm của ${cooler.name}.',
    );
  }
}

void _checkPowerConnectors(
  BuildCompatibilityResult result,
  String targetName,
  List<Map<String, dynamic>> requiredConnectors,
  List<Map<String, dynamic>> availableConnectors,
) {
  if (requiredConnectors.isEmpty) return;

  if (availableConnectors.isEmpty) {
    result.warnings.add(
      'Không thể kiểm tra đầu cấp nguồn cho $targetName vì thiếu dữ liệu các đầu nối của bộ nguồn (PSU).',
    );
    return;
  }

  for (final required in requiredConnectors) {
    final requiredType = required['type'];
    final requiredCount = _toInt(required['count'] ?? 1);

    Map<String, dynamic>? available;
    for (final connector in availableConnectors) {
      if (connector['type'] == requiredType) {
        available = connector;
        break;
      }
    }

    if (available == null) {
      _addError(
        result,
        '$targetName yêu cầu ${requiredCount}x cổng cấp nguồn loại $requiredType, nhưng bộ nguồn (PSU) không có cổng này.',
      );
      continue;
    }

    final availableCount = _toInt(available['count']);
    if (availableCount < requiredCount) {
      _addError(
        result,
        '$targetName yêu cầu ${requiredCount}x cổng cấp nguồn loại $requiredType, nhưng bộ nguồn (PSU) chỉ cung cấp $availableCount cổng.',
      );
    }
  }
}

int _estimateBuildWattage(List<BuildPart> build) {
  var total = 0;

  for (final item in build) {
    final spec = item.specifications;
    final wattage = _toInt(_get(spec, 'compatibility.tdp_w')) != 0
        ? _toInt(_get(spec, 'compatibility.tdp_w'))
        : _toInt(_get(spec, 'compatibility.processor_base_power_w')) != 0
        ? _toInt(_get(spec, 'compatibility.processor_base_power_w'))
        : _toInt(_get(spec, 'compatibility.base_power_w')) != 0
        ? _toInt(_get(spec, 'compatibility.base_power_w'))
        : _toInt(_get(spec, 'compatibility.power_w'));
    total += wattage;
  }

  final hasMainboard = build.any(
    (item) => _normalize(item.category) == 'mainboard',
  );
  final ramCount = build
      .where((item) => _normalize(item.category) == 'ram')
      .length;
  final storageCount = build
      .where((item) => _normalize(item.category) == 'ssd/hdd')
      .length;

  if (hasMainboard) total += 50;
  total += ramCount * 8;
  total += storageCount * 8;

  return total;
}
