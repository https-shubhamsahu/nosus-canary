import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../../services/focus_service.dart';
import '../../../services/audit_service.dart';
import '../../../components/study_chart.dart';
import '../../audit/providers/audit_provider.dart';

class FocusSessionNotifier extends Notifier<void> {
  Timer? _timer;

  @override
  void build() {
    _startTimer();
    ref.onDispose(() {
      _timer?.cancel();
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null) {
        FocusService.instance.incrementFocusMinutes(user.id, 1).then((_) {
          ref.read(studyTimelineProvider.notifier).refresh();
        });
      }
    });
  }

  void addFocusMinutes(int minutes) {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user != null) {
      FocusService.instance.incrementFocusMinutes(user.id, minutes).then((_) {
        ref.read(studyTimelineProvider.notifier).refresh();
      });
    }
  }
}

final focusSessionProvider = NotifierProvider<FocusSessionNotifier, void>(
  FocusSessionNotifier.new,
);

class StudyTimelineNotifier extends AsyncNotifier<List<StudyDayData>> {
  @override
  Future<List<StudyDayData>> build() async {
    final auth = ref.watch(authStateProvider).value;
    ref.watch(auditLogsProvider);

    final now = DateTime.now();
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    if (auth == null) {
      return List.generate(7, (i) {
        final date = now.subtract(Duration(days: i));
        return StudyDayData(
          day: dayNames[date.weekday - 1],
          hours: 0.0,
          scans: 0,
        );
      }).reversed.toList();
    }

    final userId = auth.id;
    final focusLogs = await FocusService.instance.fetchFocusLogs(userId);
    final auditCounts = await AuditService.instance.fetchAuditLogCounts();

    final List<StudyDayData> list = [];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayKey = DateTime(date.year, date.month, date.day);

      final dayName = dayNames[date.weekday - 1];

      final focusMinutes = focusLogs[dayKey] ?? 0;
      final hours = focusMinutes / 60.0;
      final scans = auditCounts[dayKey] ?? 0;

      list.add(StudyDayData(
        day: dayName,
        hours: double.parse(hours.toStringAsFixed(1)),
        scans: scans,
      ));
    }

    return list;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

final studyTimelineProvider = AsyncNotifierProvider<StudyTimelineNotifier, List<StudyDayData>>(
  StudyTimelineNotifier.new,
);
