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
  final double? gasTankCapacity; // LPG: litr, CNG: m3

  AppProfile({
    required this.id,
    required this.name,
    required this.carModel,
    required this.fuelType,
    this.plateNumber,
    this.gasTankCapacity,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'plateNumber': plateNumber,
      'carModel': carModel,
      'fuelType': fuelType.index,
      'gasTankCapacity': gasTankCapacity,
    };
  }

  factory AppProfile.fromMap(Map<dynamic, dynamic> map) {
    return AppProfile(
      id: map['id'] as String,
      name: map['name'] as String,
      plateNumber: map['plateNumber'] as String?,
      carModel: map['carModel'] as String,
      fuelType: FuelType.values[(map['fuelType'] ?? 0) as int],
      gasTankCapacity: (map['gasTankCapacity'] as num?)?.toDouble(),
    );
  }
}

class RefuelEntry {
  final String id;
  final DateTime date;
  final double distanceKm; // shu yoqilg‘ida yurgan km
  final double liters; // quyilgan litr
  final double pricePerLiter; // so‘m
  final bool isFullTank;

  RefuelEntry({
    required this.id,
    required this.date,
    required this.distanceKm,
    required this.liters,
    required this.pricePerLiter,
    required this.isFullTank,
  });

  double get totalCost => liters * pricePerLiter;

  /// 100 km ga sarf (l/100km)
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
    );
  }
}
