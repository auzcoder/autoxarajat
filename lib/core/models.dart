import 'package:flutter/foundation.dart';

enum FuelType {
  petrol,
  petrolLpg,
  petrolCng,
}

class AppProfile {
  final String id;
  final String name;
  final String? plateNumber;
  final String carModel;
  final FuelType fuelType;
  /// LPG bo‘lsa – litr, CNG bo‘lsa – m³. Benzinda null bo‘lishi mumkin.
  final double? gasTankCapacity;

  AppProfile({
    required this.id,
    required this.name,
    required this.carModel,
    required this.fuelType,
    this.plateNumber,
    this.gasTankCapacity,
  });

  AppProfile copyWith({
    String? id,
    String? name,
    String? plateNumber,
    String? carModel,
    FuelType? fuelType,
    double? gasTankCapacity,
  }) {
    return AppProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      plateNumber: plateNumber ?? this.plateNumber,
      carModel: carModel ?? this.carModel,
      fuelType: fuelType ?? this.fuelType,
      gasTankCapacity: gasTankCapacity ?? this.gasTankCapacity,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'plateNumber': plateNumber,
      'carModel': carModel,
      'fuelType': describeEnum(fuelType),
      'gasTankCapacity': gasTankCapacity,
    };
  }

  factory AppProfile.fromMap(Map<dynamic, dynamic> map) {
    final fuelRaw = map['fuelType'];
    FuelType ft = FuelType.petrol;
    if (fuelRaw is String) {
      switch (fuelRaw) {
        case 'petrolLpg':
          ft = FuelType.petrolLpg;
          break;
        case 'petrolCng':
          ft = FuelType.petrolCng;
          break;
        case 'petrol':
        default:
          ft = FuelType.petrol;
      }
    }

    return AppProfile(
      id: map['id'] as String? ?? 'profile_1',
      name: map['name'] as String? ?? 'Haydovchi',
      plateNumber: map['plateNumber'] as String?,
      carModel: map['carModel'] as String? ?? 'Mening avtomobilim',
      fuelType: ft,
      gasTankCapacity:
          map['gasTankCapacity'] == null ? null : (map['gasTankCapacity'] as num).toDouble(),
    );
  }
}

class RefuelEntry {
  final String id;
  final DateTime date;
  final double distanceKm;
  final double liters;
  final double pricePerLiter;
  final bool isFullTank;

  /// Qaysi avtomobilga tegishli (davlat raqami).
  /// Agar null bo‘lsa – eski / umumiy ma’lumot.
  final String? plateNumber;

  RefuelEntry({
    required this.id,
    required this.date,
    required this.distanceKm,
    required this.liters,
    required this.pricePerLiter,
    required this.isFullTank,
    this.plateNumber,
  });

  double get totalCost => liters * pricePerLiter;

  /// 100 km ga sarf (L/100km)
  double? get consumptionPer100 {
    if (distanceKm <= 0 || liters <= 0) return null;
    return (liters / distanceKm) * 100;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'distanceKm': distanceKm,
      'liters': liters,
      'pricePerLiter': pricePerLiter,
      'isFullTank': isFullTank,
      'plateNumber': plateNumber,
    };
  }

  factory RefuelEntry.fromMap(Map<dynamic, dynamic> map) {
    return RefuelEntry(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      distanceKm: (map['distanceKm'] as num).toDouble(),
      liters: (map['liters'] as num).toDouble(),
      pricePerLiter: (map['pricePerLiter'] as num).toDouble(),
      isFullTank: map['isFullTank'] as bool? ?? false,
      plateNumber: map['plateNumber'] as String?,
    );
  }
}
