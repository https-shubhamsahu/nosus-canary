import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../../services/supabase_service.dart';

class NoteState {
  final String content;
  final bool isSaving;
  const NoteState({required this.content, required this.isSaving});
}

class UserNoteNotifier extends Notifier<NoteState> {
  Timer? _debounceTimer;

  @override
  NoteState build() {
    final user = ref.watch(authStateProvider).value;

    ref.onDispose(() {
      _debounceTimer?.cancel();
      if (user != null && state.content.isNotEmpty) {
        SupabaseService.instance.saveUserNote(user.id, state.content);
      }
    });

    if (user == null) {
      return const NoteState(content: '', isSaving: false);
    }

    // Auto-load note asynchronously for the signed-in user
    _loadNote(user.id);

    return const NoteState(content: '', isSaving: false);
  }

  Future<void> _loadNote(String userId) async {
    try {
      final content = await SupabaseService.instance.fetchUserNote(userId);
      if (!ref.mounted) return;
      state = NoteState(content: content, isSaving: false);
    } catch (_) {
      if (!ref.mounted) return;
      state = const NoteState(content: '', isSaving: false);
    }
  }

  void loadNote(String userId) {
    _loadNote(userId);
  }

  void updateNote(String newContent) {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    state = NoteState(content: newContent, isSaving: true);

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 1), () async {
      await SupabaseService.instance.saveUserNote(user.id, newContent);
      if (!ref.mounted) return;
      state = NoteState(content: newContent, isSaving: false);
    });
  }
}

final userNoteProvider = NotifierProvider<UserNoteNotifier, NoteState>(
  UserNoteNotifier.new,
);
