import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';

/// Generic loading/error/data wrapper for an [AsyncValue], generalizing the
/// `.when(loading:, error:, data:)` + skeleton + error-with-retry pattern
/// originally hand-written in `groups_screen.dart` (`_SkeletonList`,
/// `_ErrorState`). Does not own a `RefreshIndicator` — callers keep their
/// own since the invalidate/await-future call differs per provider.
class AsyncStateView<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(BuildContext context, T data) data;
  final WidgetBuilder? loading;
  final String errorMessage;
  final VoidCallback onRetry;
  final bool Function(T data)? isEmpty;
  final WidgetBuilder? empty;

  const AsyncStateView({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.errorMessage = 'Something went wrong.',
    required this.onRetry,
    this.isEmpty,
    this.empty,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () =>
          loading?.call(context) ??
          const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          _AsyncErrorState(message: errorMessage, onRetry: onRetry),
      data: (value) {
        if (isEmpty != null && empty != null && isEmpty!(value)) {
          return empty!(context);
        }
        return data(context, value);
      },
    );
  }
}

class _AsyncErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _AsyncErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final subtle = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.4);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(
          parent: NoSusTheme.getScrollPhysics(context),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off_outlined, size: 36, color: subtle),
                const SizedBox(height: 12),
                Text(message, style: TextStyle(color: subtle, fontSize: 14)),
                const SizedBox(height: 16),
                Semantics(
                  button: true,
                  label: 'Retry',
                  child: InkWell(
                    onTap: onRetry,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Text(
                        'RETRY',
                        style: TextStyle(
                          fontSize: 11,
                          color: subtle,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
