import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../theme.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../config/presentation/providers/config_provider.dart';
import '../../../../core/utils/debug_logger.dart';

/// The Super Admin Console for Platform Operations.
/// Accessible only to authenticated users with 'admin' or 'super_admin' roles.
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;

  // State for feature flags
  List<Map<String, dynamic>> _flags = [];
  // State for remote configs
  List<Map<String, dynamic>> _configs = [];
  // State for system metrics
  Map<String, dynamic> _metrics = {
    'total_users': 0,
    'total_files': 0,
    'total_links': 0,
    'total_views': 0,
    'storage_bytes': 0,
  };
  // State for users list
  List<Map<String, dynamic>> _users = [];
  String _userSearchQuery = '';
  // State for admin audit logs
  List<Map<String, dynamic>> _auditLogs = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _loadFeatureFlags(),
        _loadRemoteConfigs(),
        _loadSystemMetrics(),
        _loadUsers(),
        _loadAuditLogs(),
      ]);
    } catch (e) {
      _showSnackBar('Error loading admin data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFeatureFlags() async {
    final data = await _supabase.from('feature_flags').select().order('flag_key');
    setState(() => _flags = List<Map<String, dynamic>>.from(data));
  }

  Future<void> _loadRemoteConfigs() async {
    final data = await _supabase.from('remote_configs').select().order('config_key');
    setState(() => _configs = List<Map<String, dynamic>>.from(data));
  }

  Future<void> _loadSystemMetrics() async {
    try {
      final userCountRes = await _supabase.from('profiles').select('id');
      final fileCountRes = await _supabase.from('secure_files').select('id');
      final linkCountRes = await _supabase.from('share_links').select('id');
      final viewCountRes = await _supabase.from('share_link_views').select('id');
      
      // Sum storage bytes
      final filesData = await _supabase.from('secure_files').select('size');
      final totalSize = filesData.fold<int>(0, (sum, f) => sum + ((f['size'] as num?)?.toInt() ?? 0));

      setState(() {
        _metrics = {
          'total_users': userCountRes.length,
          'total_files': fileCountRes.length,
          'total_links': linkCountRes.length,
          'total_views': viewCountRes.length,
          'storage_bytes': totalSize,
        };
      });
    } catch (e) {
      debugLog('Metrics loading error: $e');
    }
  }


  Future<void> _loadUsers() async {
    // Queries profiles and left joins their roles
    var query = _supabase.from('profiles').select('id, display_name, email, created_at, user_roles(role)');
    if (_userSearchQuery.trim().isNotEmpty) {
      query = query.or('display_name.ilike.%$_userSearchQuery%,email.ilike.%$_userSearchQuery%');
    }
    final data = await query.limit(20);
    setState(() => _users = List<Map<String, dynamic>>.from(data));
  }

  Future<void> _loadAuditLogs() async {
    final data = await _supabase
        .from('admin_audit_logs')
        .select('*, profiles!admin_audit_logs_admin_id_fkey(display_name, email)')
        .order('created_at', ascending: false)
        .limit(30);
    setState(() => _auditLogs = List<Map<String, dynamic>>.from(data));
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<String?> _promptJustification(String actionName) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final fg = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text(
            'LOG ADMINISTRATIVE ACTION',
            style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.0),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Action: $actionName\n\nAdministrative regulations require a justification for audit logs. Please specify a reason:',
                style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 11, height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(color: fg, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'e.g. Disabling watermark for beta performance testing',
                  hintStyle: TextStyle(color: fg.withValues(alpha: 0.3)),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontSize: 11)),
            ),
            TextButton(
              onPressed: () {
                final reason = controller.text.trim();
                if (reason.isNotEmpty) {
                  Navigator.pop(context, reason);
                }
              },
              child: Text('SUBMIT LOG', style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateFlag(String flagKey, bool currentActive, bool newActive, int percentage) async {
    final reason = await _promptJustification('Modify Feature Flag: $flagKey -> ${newActive ? "ENABLED" : "DISABLED"} ($percentage% rollout)');
    if (reason == null) return;

    final adminUser = ref.read(authStateProvider).value;
    if (adminUser == null) return;

    setState(() => _isLoading = true);

    try {
      final oldRecord = _flags.firstWhere((element) => element['flag_key'] == flagKey);
      
      // Update DB
      await _supabase.from('feature_flags').update({
        'is_active': newActive,
        'rollout_percentage': percentage,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('flag_key', flagKey);

      // Create Admin Audit Log
      await _supabase.from('admin_audit_logs').insert({
        'admin_id': adminUser.id,
        'action': 'TOGGLE_FEATURE_FLAG',
        'target_table': 'feature_flags',
        'target_key': flagKey,
        'previous_value': oldRecord,
        'new_value': {'is_active': newActive, 'rollout_percentage': percentage},
        'reason': reason,
      });

      _showSnackBar('Feature flag "$flagKey" successfully updated.');
      await _loadFeatureFlags();
      await _loadAuditLogs();
      
      // Refresh local cache via Riverpod invalidate
      ref.invalidate(remoteConfigServiceProvider);
    } catch (e) {
      _showSnackBar('Update failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateConfig(String key, dynamic newValue) async {
    final reason = await _promptJustification('Modify Config parameter: $key -> $newValue');
    if (reason == null) return;

    final adminUser = ref.read(authStateProvider).value;
    if (adminUser == null) return;

    setState(() => _isLoading = true);

    try {
      final oldRecord = _configs.firstWhere((element) => element['config_key'] == key);

      // Update DB
      await _supabase.from('remote_configs').update({
        'config_value': newValue,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('config_key', key);

      // Create Admin Audit Log
      await _supabase.from('admin_audit_logs').insert({
        'admin_id': adminUser.id,
        'action': 'UPDATE_REMOTE_CONFIG',
        'target_table': 'remote_configs',
        'target_key': key,
        'previous_value': oldRecord,
        'new_value': {'config_value': newValue},
        'reason': reason,
      });

      _showSnackBar('Remote configuration "$key" successfully updated.');
      await _loadRemoteConfigs();
      await _loadAuditLogs();
      
      // Refresh local cache
      ref.invalidate(remoteConfigServiceProvider);
    } catch (e) {
      _showSnackBar('Update failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _changeUserRole(String userId, String email, String oldRole, String newRole) async {
    final reason = await _promptJustification('Change user role: $email ($oldRole -> $newRole)');
    if (reason == null) return;

    final adminUser = ref.read(authStateProvider).value;
    if (adminUser == null) return;

    setState(() => _isLoading = true);

    try {
      // Update DB role
      await _supabase.from('user_roles').upsert({
        'user_id': userId,
        'role': newRole.toLowerCase(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      // Log action
      await _supabase.from('admin_audit_logs').insert({
        'admin_id': adminUser.id,
        'action': 'CHANGE_USER_ROLE',
        'target_table': 'user_roles',
        'target_key': userId,
        'previous_value': {'role': oldRole},
        'new_value': {'role': newRole},
        'reason': reason,
      });

      _showSnackBar('Successfully elevated $email to $newRole.');
      await _loadUsers();
      await _loadAuditLogs();
    } catch (e) {
      _showSnackBar('Role elevation failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'PLATFORM SUPER ADMIN CONSOLE',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: fg),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: fg),
            onPressed: _loadAllData,
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: fg,
          labelColor: fg,
          unselectedLabelColor: fg.withValues(alpha: 0.4),
          labelStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0),
          tabs: const [
            Tab(text: 'METRICS'),
            Tab(text: 'FEATURE FLAGS'),
            Tab(text: 'REMOTE CONFIG'),
            Tab(text: 'USERS'),
            Tab(text: 'AUDIT LOGS'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 1.5))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMetricsTab(fg),
                _buildFlagsTab(fg),
                _buildConfigsTab(fg),
                _buildUsersTab(fg),
                _buildAuditLogsTab(fg),
              ],
            ),
    );
  }

  Widget _buildMetricsTab(Color fg) {
    final double storageMB = _metrics['storage_bytes'] / (1024 * 1024);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SECURESEND SYSTEM TELEMETRY',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg.withValues(alpha: 0.5), letterSpacing: 1.0),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.3,
            children: [
              _buildMetricCard('TOTAL ENROLLED USERS', '${_metrics['total_users']}', fg),
              _buildMetricCard('SECURE FILES UPLOADED', '${_metrics['total_files']}', fg),
              _buildMetricCard('ACTIVE SHARE LINKS', '${_metrics['total_links']}', fg),
              _buildMetricCard('TOTAL SECURE VIEWS LOGGED', '${_metrics['total_views']}', fg),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: NoSusTheme.cardDecoration(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL STORAGE SIZE',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: fg.withValues(alpha: 0.4), letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${storageMB.toStringAsFixed(2)} MB',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: fg),
                    ),
                  ],
                ),
                Icon(Icons.cloud_queue, size: 28, color: fg.withValues(alpha: 0.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String val, Color fg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: NoSusTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            val,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: fg),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: fg.withValues(alpha: 0.4), letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildFlagsTab(Color fg) {
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _flags.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, idx) {
        final flag = _flags[idx];
        final key = flag['flag_key'] as String;
        final isActive = flag['is_active'] as bool? ?? false;
        final rollout = flag['rollout_percentage'] as int? ?? 100;
        final desc = flag['description'] as String? ?? '';

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: NoSusTheme.cardDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      key,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: fg),
                    ),
                  ),
                  Switch(
                    value: isActive,
                    activeTrackColor: Colors.green,
                    onChanged: (val) {
                      _updateFlag(key, isActive, val, rollout);
                    },
                  )
                ],
              ),
              const SizedBox(height: 6),
              Text(
                desc,
                style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.6), height: 1.4),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ROLLOUT STAGE: $rollout%',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: fg.withValues(alpha: 0.4)),
                  ),
                  SizedBox(
                    width: 140,
                    child: SliderTheme(
                      data: SliderThemeData(
                        overlayShape: SliderComponentShape.noOverlay,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      ),
                      child: Slider(
                        value: rollout.toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 10,
                        activeColor: fg,
                        inactiveColor: fg.withValues(alpha: 0.15),
                        onChanged: (val) {
                          // update via state first to show slide locally, then confirm update
                        },
                        onChangeEnd: (val) {
                          _updateFlag(key, isActive, isActive, val.toInt());
                        },
                      ),
                    ),
                  )
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildConfigsTab(Color fg) {
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _configs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, idx) {
        final config = _configs[idx];
        final key = config['config_key'] as String;
        final rawVal = config['config_value'];
        final desc = config['description'] as String? ?? '';

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: NoSusTheme.cardDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                key,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: fg),
              ),
              const SizedBox(height: 6),
              Text(
                desc,
                style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.6), height: 1.4),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'VALUE: ${jsonEncode(rawVal)}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit, size: 16, color: fg),
                    onPressed: () async {
                      // Prompt for new value
                      final textController = TextEditingController(text: rawVal.toString());
                      final newVal = await showDialog<dynamic>(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            backgroundColor: Theme.of(context).cardColor,
                            title: const Text('EDIT CONFIG VALUE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            content: TextField(
                              controller: textController,
                              style: TextStyle(color: fg, fontSize: 13),
                              decoration: const InputDecoration(border: OutlineInputBorder()),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('CANCEL')),
                              TextButton(
                                onPressed: () {
                                  final input = textController.text.trim();
                                  // Attempt parsing to dynamic int / double / bool or keep string
                                  if (input == 'true') {
                                    Navigator.pop(context, true);
                                  } else if (input == 'false') {
                                    Navigator.pop(context, false);
                                  } else if (int.tryParse(input) != null) {
                                    Navigator.pop(context, int.parse(input));
                                  } else if (double.tryParse(input) != null) {
                                    Navigator.pop(context, double.parse(input));
                                  } else {
                                    Navigator.pop(context, input);
                                  }
                                },
                                child: const Text('SAVE'),
                              ),
                            ],
                          );
                        },
                      );
                      if (newVal != null) {
                        _updateConfig(key, newVal);
                      }
                    },
                  )
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildUsersTab(Color fg) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: TextField(
            style: TextStyle(color: fg, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search display name or email...',
              hintStyle: TextStyle(color: fg.withValues(alpha: 0.3)),
              prefixIcon: Icon(Icons.search, size: 16, color: fg.withValues(alpha: 0.5)),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (val) {
              setState(() => _userSearchQuery = val);
              _loadUsers();
            },
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _users.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: fg.withValues(alpha: 0.08)),
            itemBuilder: (context, idx) {
              final user = _users[idx];
              final id = user['id'] as String;
              final email = user['email'] as String? ?? 'No Email';
              final name = user['display_name'] as String? ?? 'No Name';
              final rolesData = user['user_roles'] as Map<String, dynamic>?;
              final role = (rolesData?['role'] as String? ?? 'user').toUpperCase();

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                title: Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(email, style: TextStyle(fontSize: 10, color: fg.withValues(alpha: 0.5))),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: role == 'SUPER_ADMIN' ? Colors.redAccent.withValues(alpha: 0.1) : fg.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        role,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: role == 'SUPER_ADMIN' ? Colors.redAccent : fg.withValues(alpha: 0.6),
                        ),
                      ),
                    )
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 16, color: fg),
                  onSelected: (val) {
                    _changeUserRole(id, email, role, val);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'user', child: Text('DEMOTE TO USER', style: TextStyle(fontSize: 10))),
                    const PopupMenuItem(value: 'operator', child: Text('ELEVATE TO OPERATOR', style: TextStyle(fontSize: 10))),
                    const PopupMenuItem(value: 'admin', child: Text('ELEVATE TO ADMIN', style: TextStyle(fontSize: 10))),
                    const PopupMenuItem(value: 'super_admin', child: Text('ELEVATE TO SUPER ADMIN', style: TextStyle(fontSize: 10))),
                  ],
                ),
              );
            },
          ),
        )
      ],
    );
  }

  Widget _buildAuditLogsTab(Color fg) {
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _auditLogs.length,
      separatorBuilder: (context, index) => Divider(height: 1, color: fg.withValues(alpha: 0.08)),
      itemBuilder: (context, idx) {
        final log = _auditLogs[idx];
        final action = log['action'] as String;
        final key = log['target_key'] as String;
        final profilesData = log['profiles'] as Map<String, dynamic>?;
        final adminEmail = profilesData?['email'] as String? ?? 'Unknown Admin';
        final reason = log['reason'] as String;
        final dateStr = DateTime.parse(log['created_at'] as String).toLocal().toString().substring(5, 16);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: fg.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      action,
                      style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: fg),
                    ),
                  ),
                  Text(
                    dateStr,
                    style: TextStyle(fontSize: 9, color: fg.withValues(alpha: 0.4)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Key: $key',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
              ),
              const SizedBox(height: 4),
              Text(
                'Justification: "$reason"',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: fg.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 6),
              Text(
                'By: $adminEmail',
                style: TextStyle(fontSize: 9, color: fg.withValues(alpha: 0.5)),
              )
            ],
          ),
        );
      },
    );
  }
}
