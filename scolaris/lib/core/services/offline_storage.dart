import 'package:hive_flutter/hive_flutter.dart';

/// Lightweight offline cache + outbox for actions performed while offline.
class OfflineStorage {
  static const _settingsBox = 'scolaris_settings';
  static const _outboxBox = 'scolaris_outbox';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_settingsBox);
    await Hive.openBox(_outboxBox);
  }

  static Box get settings => Hive.box(_settingsBox);
  static Box get outbox => Hive.box(_outboxBox);

  static Future<void> queueAction(String type, Map<String, dynamic> payload) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    return outbox.put(id, {'type': type, 'payload': payload, 'ts': id});
  }
}
