import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme.dart';
import '../../data/redemption_code_client.dart';
import 'burn_file_viewer_screen.dart';
import 'burn_note_viewer_screen.dart';

/// In-app entry point for the short-code retrieval path — the counterpart
/// to opening a Burn Note/File link, for when the sender read/typed a code
/// out instead of sending the link itself. See
/// supabase/migrations/20260713000000_burn_redemption_codes.sql for why
/// this path has a different (server briefly holds the key) guarantee than
/// the link.
class RedeemCodeScreen extends StatefulWidget {
  /// The opaque token from a `#/redeem/<token>` pairing link. It is the real
  /// credential; the visible two digits only confirm the intended share.
  final String? redeemToken;

  const RedeemCodeScreen({super.key, this.redeemToken});

  @override
  State<RedeemCodeScreen> createState() => _RedeemCodeScreenState();
}

class _RedeemCodeScreenState extends State<RedeemCodeScreen> {
  final _codeController = TextEditingController();
  final _codeFocus = FocusNode();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter a code first.');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await RedemptionCodeClient.instance.redeem(
        code,
        redeemToken: widget.redeemToken,
      );
      if (!mounted) return;
      final viewer = result.targetKind == 'file'
          ? BurnFileViewerScreen(
              files: [
                (
                  id: result.targetId,
                  keyHex: result.keyHex,
                  ivHex: result.ivHex,
                ),
              ],
            )
          : BurnNoteViewerScreen(
              noteId: result.targetId,
              keyHex: result.keyHex,
              ivHex: result.ivHex,
            );
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => viewer));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;
    final subtle = isDark
        ? NoSusTheme.dTextSecondary
        : NoSusTheme.lTextSecondary;

    return Scaffold(
      appBar: AppBar(title: const Text('Redeem a Code')),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(
            parent: NoSusTheme.getScrollPhysics(context),
          ),
          padding: const EdgeInsets.all(NoSusTheme.s24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.key_outlined,
                size: 40,
                color: fg.withValues(alpha: 0.6),
              ),
              const SizedBox(height: NoSusTheme.s16),
              Text(
                'Got a code instead of a link?',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: NoSusTheme.s8),
              Text(
                widget.redeemToken == null
                    ? 'Open the secure pairing link first, then enter its '
                          'two-digit confirmation code. This screen also accepts '
                          'an older 8-character code while existing shares expire.'
                    : 'Enter the two digits the sender gave you. The secure '
                          'link you opened is the access credential; these digits '
                          'simply confirm the right share.',
                style: theme.textTheme.bodyMedium?.copyWith(color: subtle),
              ),
              const SizedBox(height: NoSusTheme.s32),
              TextField(
                controller: _codeController,
                focusNode: _codeFocus,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                maxLength: widget.redeemToken == null ? 8 : 2,
                style: theme.textTheme.titleLarge?.copyWith(
                  letterSpacing: 4,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                decoration: InputDecoration(
                  hintText: widget.redeemToken == null ? 'ABCD1234' : '00',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(NoSusTheme.r12),
                  ),
                  errorText: _error,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    widget.redeemToken == null
                        ? RegExp(r'[A-Za-z0-9]')
                        : RegExp(r'[0-9]'),
                  ),
                  TextInputFormatter.withFunction(
                    (oldValue, newValue) => newValue.copyWith(
                      text: widget.redeemToken == null
                          ? newValue.text.toUpperCase()
                          : newValue.text,
                    ),
                  ),
                ],
                onSubmitted: (_) => _submit(),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: NoSusTheme.s24),
              SizedBox(
                width: double.infinity,
                child: Semantics(
                  button: true,
                  enabled: !_isLoading,
                  label: _isLoading ? 'Opening' : 'Open code',
                  child: GestureDetector(
                    onTap: _isLoading ? null : _submit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: fg,
                        borderRadius: BorderRadius.circular(NoSusTheme.r12),
                      ),
                      child: Center(
                        child: _isLoading
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: isDark ? Colors.black : Colors.white,
                                ),
                              )
                            : Text(
                                'OPEN',
                                style: TextStyle(
                                  color: isDark ? Colors.black : Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
