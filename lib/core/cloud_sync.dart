// import 'dart:convert';
// import 'dart:io';

// import 'package:flutter/services.dart';
// import 'package:hive_flutter/hive_flutter.dart';

// import 'models.dart';
// import 'storage.dart';

// /// iCloud Key-Value Store bilan sync qilish uchun servis.
// /// iOS / macOS da ishlaydi, boshqa platformalarda hech narsa qilmaydi.
// class CloudSyncService {
//   CloudSyncService._();
//   static final CloudSyncService instance = CloudSyncService._();

//   static const MethodChannel _channel = MethodChannel('autoxarajat/cloud');

//   bool get isSupported => Platform.isIOS || Platform.isMacOS;

//   /// iCloud ichida biz bir plate uchun shunday JSON saqlaymiz:
//   /// {
//   ///   "profile": {...},
//   ///   "entries": [...],
//   ///   "services": [...]
//   /// }
//   Future<void> saveToCloud(Box box) async {
//     if (!isSupported) return;

//     final profileMap = box.get('profile
