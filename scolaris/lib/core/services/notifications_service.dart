import 'dart:async';

/// In-app notifications channel. A real impl wires Firebase / OneSignal /
/// Supabase realtime. For now, an in-memory broadcast suffices for the shell.
class NotificationsService {
  NotificationsService._();
  static final I = NotificationsService._();

  final _ctrl = StreamController<AppNotification>.broadcast();
  Stream<AppNotification> get stream => _ctrl.stream;

  void push(AppNotification n) => _ctrl.add(n);
}

class AppNotification {
  final String title;
  final String body;
  final DateTime when;
  AppNotification({required this.title, required this.body, DateTime? when})
      : when = when ?? DateTime.now();
}
