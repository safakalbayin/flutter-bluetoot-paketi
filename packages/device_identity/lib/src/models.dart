class AndroidDeviceDetails {
  const AndroidDeviceDetails({
    required this.manufacturer,
    required this.brand,
    required this.model,
    required this.device,
    required this.product,
    required this.hardware,
    required this.androidVersion,
    required this.sdkInt,
    required this.supportedAbis,
    required this.totalRamBytes,
    required this.totalStorageBytes,
    required this.availableStorageBytes,
    required this.hasTelephony,
    this.securityPatch,
  });

  factory AndroidDeviceDetails.fromMap(Map<Object?, Object?> map) =>
      AndroidDeviceDetails(
        manufacturer: map['manufacturer'] as String,
        brand: map['brand'] as String,
        model: map['model'] as String,
        device: map['device'] as String,
        product: map['product'] as String,
        hardware: map['hardware'] as String,
        androidVersion: map['androidVersion'] as String,
        sdkInt: map['sdkInt'] as int,
        supportedAbis: List<String>.from(map['supportedAbis'] as List),
        securityPatch: map['securityPatch'] as String?,
        totalRamBytes: map['totalRamBytes'] as int,
        totalStorageBytes: map['totalStorageBytes'] as int,
        availableStorageBytes: map['availableStorageBytes'] as int,
        hasTelephony: map['hasTelephony'] as bool,
      );

  final String manufacturer;
  final String brand;
  final String model;
  final String device;
  final String product;
  final String hardware;
  final String androidVersion;
  final int sdkInt;
  final List<String> supportedAbis;
  final String? securityPatch;
  /// OS-visible physical RAM, not marketing capacity or free memory.
  final int totalRamBytes;
  /// Internal data partition capacity; not the device's marketed storage size.
  final int totalStorageBytes;
  final int availableStorageBytes;
  final bool hasTelephony;
}

enum PhonePermissionStatus { granted, denied, restricted, notRequired }

class PhonePermissionResult {
  const PhonePermissionResult({required this.status, required this.message});

  factory PhonePermissionResult.fromMap(Map<Object?, Object?> map) =>
      PhonePermissionResult(
        status: PhonePermissionStatus.values.byName(map['status'] as String),
        message: map['message'] as String,
      );

  final PhonePermissionStatus status;
  final String message;
}

enum ImeiStatus {
  available,
  permissionRequired,
  restricted,
  unavailable,
  noTelephony,
}

class ImeiEntry {
  const ImeiEntry({
    required this.slotIndex,
    required this.status,
    required this.message,
    required this.imei,
  });

  factory ImeiEntry.fromMap(Map<Object?, Object?> map) => ImeiEntry(
    slotIndex: map['slotIndex'] as int,
    status: ImeiStatus.values.byName(map['status'] as String),
    message: map['message'] as String,
    imei: map['imei'] as String?,
  );

  /// Zero-based modem slot. This does not imply a SIM card is inserted.
  final int slotIndex;
  final ImeiStatus status;
  final String message;
  final String? imei;
}

class ImeiReport {
  const ImeiReport({
    required this.status,
    required this.message,
    required this.entries,
  });

  factory ImeiReport.fromMap(Map<Object?, Object?> map) => ImeiReport(
    status: ImeiStatus.values.byName(map['status'] as String),
    message: map['message'] as String,
    entries: (map['entries'] as List)
        .map((item) => ImeiEntry.fromMap(Map<Object?, Object?>.from(item as Map)))
        .toList(growable: false),
  );

  final ImeiStatus status;
  final String message;
  final List<ImeiEntry> entries;
}
