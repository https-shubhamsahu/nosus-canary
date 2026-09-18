import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/audit_service.dart';
import '../../auth/presentation/providers/auth_providers.dart';

class AuditLogsNotifier extends AsyncNotifier<List<Map<String, String>>> {
  StreamSubscription? _sub;

  @override
  Future<List<Map<String, String>>> build() async {
    final user = ref.watch(authStateProvider).value;

    _sub?.cancel();
    ref.onDispose(() => _sub?.cancel());

    if (user == null) {
      AuditService.instance.reset();
      return const [];
    }

    // Re-initialize AuditService with the new user session
    AuditService.instance.init();

    _sub = AuditService.instance.watchAuditLogs().listen((data) {
      state = AsyncValue.data(data);
    });

    return AuditService.instance.auditLogs;
  }

  void addLog(String event, String status) {
    AuditService.instance.logEvent(event, status);
  }
}

final auditLogsProvider =
    AsyncNotifierProvider<AuditLogsNotifier, List<Map<String, String>>>(
      AuditLogsNotifier.new,
    );
