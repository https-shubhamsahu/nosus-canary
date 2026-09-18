import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../theme.dart';
import '../../../../config/supabase_credentials.dart';
import '../../../../core/mascot/mascot_state.dart';
import '../../../../core/mascot/mascot_view.dart';

class AdvancedSettingsScreen extends ConsumerStatefulWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  ConsumerState<AdvancedSettingsScreen> createState() =>
      _AdvancedSettingsScreenState();
}

class _AdvancedSettingsScreenState
    extends ConsumerState<AdvancedSettingsScreen> {
  bool _isTestingLatency = false;
  int _latencyMs = -1;

  Future<void> _testLatency() async {
    if (_isTestingLatency) return;
    setState(() {
      _isTestingLatency = true;
      _latencyMs = -1;
    });

    final stopwatch = Stopwatch()..start();
    try {
      final uri = Uri.parse('${SupabaseCredentials.url}/rest/v1/');
      final response = await http
          .get(uri, headers: {'apikey': SupabaseCredentials.anonKey})
          .timeout(const Duration(seconds: 4));
      stopwatch.stop();
      if (response.statusCode == 200) {
        setState(() {
          _latencyMs = stopwatch.elapsedMilliseconds;
        });
      } else {
        setState(() {
          _latencyMs = -2; // server error
        });
      }
    } catch (_) {
      setState(() {
        _latencyMs = -3; // timeout / offline
      });
    } finally {
      setState(() {
        _isTestingLatency = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: fg),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ADVANCED SETTINGS',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            const MascotView(character: MascotCharacter.nox, size: 18),
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'NETWORK DIAGNOSTICS',
              style: theme.textTheme.labelLarge?.copyWith(
                color: fg.withValues(alpha: 0.4),
                fontSize: 10,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: NoSusTheme.cardDecoration(context),
              child: Column(
                children: [
                  _buildDiagRow(
                    context,
                    'System Endpoint',
                    SupabaseCredentials.url.replaceFirst('https://', ''),
                  ),
                  const SizedBox(height: 12),
                  _buildDiagRow(
                    context,
                    'Tunnel Latency',
                    _latencyMs == -1
                        ? 'Not Pinged'
                        : _latencyMs == -2
                        ? 'Gateway Timeout'
                        : _latencyMs == -3
                        ? 'Offline Mode'
                        : '${_latencyMs}ms',
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    button: true,
                    label: _isTestingLatency
                        ? 'Testing connection latency'
                        : 'Test connection latency',
                    child: GestureDetector(
                      onTap: _testLatency,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: fg.withValues(alpha: 0.2)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: _isTestingLatency
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: Colors.grey,
                                  ),
                                )
                              : Text(
                                  'TEST LATENCY',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontSize: 10,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagRow(BuildContext context, String label, String value) {
    final fg = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: fg.withValues(alpha: 0.5),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: fg,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}
