import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../theme.dart';
import '../providers/groups_provider.dart';

class JoinGroupPage extends ConsumerStatefulWidget {
  const JoinGroupPage({super.key});

  @override
  ConsumerState<JoinGroupPage> createState() => _JoinGroupPageState();
}

class _JoinGroupPageState extends ConsumerState<JoinGroupPage> {
  final _codeController = TextEditingController();
  bool _isJoining = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleJoin() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isJoining = true);
    HapticFeedback.mediumImpact();

    try {
      await ref.read(groupsProvider.notifier).joinByInviteCode(code);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully joined the group!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join: ${_cleanError(e)}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  String _cleanError(Object e) => e
      .toString()
      .replaceAll('Exception: ', '')
      .replaceAll(RegExp(r'^PostgrestException\(message: '), '')
      .replaceAll(RegExp(r', code: .*\)$'), '');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;
    final bg = theme.scaffoldBackgroundColor;
    final subtle = isDark ? NoSusTheme.dTextSecondary : NoSusTheme.lTextSecondary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: fg),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                'JOIN SECURE GROUP',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1.0,
                  color: fg,
                ),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
              const SizedBox(height: 8),
              Text(
                'Enter the secure invite code provided by the group admin to request access.',
                style: TextStyle(
                  color: subtle,
                  fontSize: 15,
                  height: 1.4,
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
              const SizedBox(height: 48),
              TextField(
                controller: _codeController,
                style: TextStyle(color: fg, fontSize: 24, letterSpacing: 4.0, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'CODE-XYZ',
                  hintStyle: TextStyle(color: subtle.withValues(alpha: 0.3), letterSpacing: 4.0),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 24),
                ),
                textCapitalization: TextCapitalization.characters,
              ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isJoining ? null : _handleJoin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: fg,
                    foregroundColor: bg,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isJoining
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: bg,
                          ),
                        )
                      : const Text(
                          'JOIN GROUP',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            fontSize: 15,
                          ),
                        ),
                ),
              ).animate().fadeIn(delay: 300.ms, duration: 300.ms),
            ],
          ),
        ),
      ),
    );
  }
}
