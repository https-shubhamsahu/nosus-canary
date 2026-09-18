import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart' as fp;
import '../models/group_file.dart';
import '../../../theme.dart';
import '../../files/domain/models/secure_file_metadata.dart';
import '../../files/presentation/providers/secure_file_providers.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../profile/providers/profile_provider.dart';
import '../../files/presentation/providers/upload_provider.dart';
import '../../../core/utils/debug_logger.dart';
import '../../../core/mascot/mascot_controller.dart';
import '../../../core/mascot/mascot_state.dart';
import '../../../core/mascot/mascot_view.dart';

/// Premium upload bottom sheet. Slides up via DraggableScrollableSheet.
/// States: pick/link → processing (animated progress) → complete (checkmark).
class UploadModal extends ConsumerStatefulWidget {
  final String groupId;

  const UploadModal({super.key, required this.groupId});

  @override
  ConsumerState<UploadModal> createState() => _UploadModalState();
}

class _UploadModalState extends ConsumerState<UploadModal>
    with SingleTickerProviderStateMixin {
  FileType? _selectedType;
  late AnimationController _checkController;
  late Animation<double> _checkProgress;

  // New Link from Google Drive state
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _urlFocus = FocusNode();
  FileType _linkType = FileType.pdf;
  bool _isLinking = false;
  int _activeTab = 0; // 0 = upload local, 1 = link drive
  String? _serviceAccountEmail;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkProgress = CurvedAnimation(
      parent: _checkController,
      curve: Curves.easeOut,
    );
    _loadServiceAccountEmail();
  }

  @override
  void dispose() {
    _checkController.dispose();
    _urlController.dispose();
    _nameController.dispose();
    _nameFocus.dispose();
    _urlFocus.dispose();
    super.dispose();
  }

  Future<void> _loadServiceAccountEmail() async {
    if (!mounted) return;
    try {
      final email = await ref
          .read(secureFileRepositoryProvider)
          .getServiceAccountEmail();
      if (mounted) {
        setState(() {
          _serviceAccountEmail = email;
        });
      }
    } catch (_) {}
  }

  Future<void> _linkDocument() async {
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();

    if (name.isEmpty || url.isEmpty) {
      _showErrorSnackBar(
        "Please enter both a document name and a Google Drive URL.",
      );
      return;
    }

    setState(() => _isLinking = true);
    HapticFeedback.mediumImpact();

    try {
      final domainType = SecureFileType.values.firstWhere(
        (e) => e.name == _linkType.name,
        orElse: () => SecureFileType.pdf,
      );

      final currentUser = ref.read(authRepositoryProvider).currentUser;
      final profileVal = ref.read(profileProvider).value;
      final uploaderName =
          profileVal?.displayName ?? currentUser?.email ?? 'Anonymous';
      String uploaderInitials = 'AN';
      if (uploaderName.isNotEmpty) {
        if (uploaderName.contains('@')) {
          final prefix = uploaderName.split('@').first;
          uploaderInitials = prefix
              .substring(0, prefix.length >= 2 ? 2 : prefix.length)
              .toUpperCase();
        } else {
          uploaderInitials = uploaderName
              .substring(0, uploaderName.length >= 2 ? 2 : uploaderName.length)
              .toUpperCase();
        }
      }

      await ref
          .read(secureFileRepositoryProvider)
          .addGoogleDriveLink(
            groupId: widget.groupId,
            name: name,
            type: domainType,
            driveUrl: url,
            uploaderName: uploaderName,
            uploaderInitials: uploaderInitials,
          );

      if (mounted) {
        // Trigger completion animation!
        ref.read(uploadProvider.notifier).reset(); // ensure state is clear
        setState(() => _isLinking = false);
        _checkController.forward().then((_) {
          if (mounted) {
            Navigator.of(context).pop(); // close modal after complete
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLinking = false);
        _showErrorSnackBar("Error linking file: $e");
      }
    }
  }

  Future<void> _startUpload(FileType type) async {
    HapticFeedback.lightImpact();

    fp.FileType pickerType;
    List<String>? allowedExtensions;

    switch (type) {
      case FileType.pdf:
        pickerType = fp.FileType.custom;
        allowedExtensions = ['pdf'];
        break;
      case FileType.image:
        pickerType = fp.FileType.image;
        break;
      case FileType.markdown:
        pickerType = fp.FileType.custom;
        allowedExtensions = ['md', 'txt'];
        break;
      case FileType.scan:
        pickerType = fp.FileType.custom;
        allowedExtensions = ['jpg', 'jpeg', 'png', 'pdf'];
        break;
    }

    try {
      final result = await fp.FilePicker.pickFiles(
        type: pickerType,
        allowedExtensions: allowedExtensions,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        debugLog("File picker: User cancelled picking");
        return;
      }

      final file = result.files.first;

      // Enforce 10MB limit per file
      if (file.size > 10 * 1024 * 1024) {
        _showErrorSnackBar(
          "File exceeds 10MB limit. Please select a smaller file.",
        );
        return;
      }

      final name = file.name;
      final bytes = file.bytes;

      if (bytes == null) {
        if (file.path != null) {
          final ioFile = File(file.path!);
          final fileBytes = await ioFile.readAsBytes();
          _uploadRealFile(name, type, fileBytes);
        } else {
          _showErrorSnackBar("Could not read file data. Try another file.");
        }
      } else {
        _uploadRealFile(name, type, bytes);
      }
    } catch (e) {
      debugLog("File picker error: $e");
      _showErrorSnackBar("Error picking file: $e");
    }
  }

  void _uploadRealFile(String fileName, FileType type, Uint8List bytes) {
    ref
        .read(uploadProvider.notifier)
        .uploadDocument(fileName, type, widget.groupId, bytes);
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<UploadState>(uploadProvider, (previous, next) {
      if (next.stage == previous?.stage) return;
      switch (next.stage) {
        case UploadStage.processing:
          ref.read(luxMascotProvider.notifier).play(MascotMood.think);
          break;
        case UploadStage.complete:
          ref.read(luxMascotProvider.notifier).play(MascotMood.celebrate);
          break;
        case UploadStage.error:
          ref.read(noxMascotProvider.notifier).play(MascotMood.alert);
          break;
        default:
          break;
      }
    });
    final upload = ref.watch(uploadProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? NoSusTheme.dCard : NoSusTheme.lCard;
    final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;
    final subtle = isDark
        ? NoSusTheme.dTextSecondary
        : NoSusTheme.lTextSecondary;

    final displayEmail =
        _serviceAccountEmail ?? "Supabase Storage (no service account)";

    // Auto-trigger checkmark when complete
    final isComplete =
        (upload.stage == UploadStage.complete) || (_checkController.value > 0);
    final isProcessing = (upload.stage == UploadStage.processing);
    final isError = (upload.stage == UploadStage.error);

    if (upload.stage == UploadStage.complete && !_checkController.isCompleted) {
      _checkController.forward();
    } else if (upload.stage == UploadStage.idle &&
        _checkController.value == 0) {
      _selectedType = null;
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: fg.withValues(alpha: 0.1), width: 0.75),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 3,
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // ── Content based on upload state ─────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: () {
              if (isComplete) {
                return _CompleteState(
                  key: const ValueKey('complete'),
                  checkProgress: _checkProgress,
                  fg: fg,
                );
              }
              if (isProcessing) {
                return _ProcessingState(
                  key: const ValueKey('processing'),
                  fileName: upload.fileName ?? '',
                  progress: upload.progress,
                  fg: fg,
                  subtle: subtle,
                  onCancel: () =>
                      ref.read(uploadProvider.notifier).cancelUpload(),
                );
              }
              if (isError) {
                return _ErrorState(
                  key: const ValueKey('error'),
                  message: upload.errorMessage ?? 'Upload failed',
                  fg: fg,
                  onRetry: () => ref.read(uploadProvider.notifier).reset(),
                );
              }

              // Idle / Picking - Render selector tabs
              return Column(
                key: const ValueKey('picker_tabs'),
                children: [
                  // Tab selection row
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: NoSusTheme.s24,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: _activeTab == 0,
                            label: 'Upload local file',
                            child: GestureDetector(
                              onTap: () => setState(() => _activeTab = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _activeTab == 0
                                          ? fg
                                          : Colors.transparent,
                                      width: 2.0,
                                    ),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    "UPLOAD LOCAL",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                      color: _activeTab == 0
                                          ? fg
                                          : fg.withValues(alpha: 0.4),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: _activeTab == 1,
                            label: 'Link a Google Drive URL',
                            child: GestureDetector(
                              onTap: () => setState(() => _activeTab = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _activeTab == 1
                                          ? fg
                                          : Colors.transparent,
                                      width: 2.0,
                                    ),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    "LINK DRIVE URL",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                      color: _activeTab == 1
                                          ? fg
                                          : fg.withValues(alpha: 0.4),
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
                  const SizedBox(height: 20),

                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _activeTab == 0
                        ? _PickerState(
                            key: const ValueKey('picker'),
                            fg: fg,
                            subtle: subtle,
                            selectedType: _selectedType,
                            onTypeSelected: (type) {
                              setState(() => _selectedType = type);
                              _startUpload(type);
                            },
                          )
                        : _LinkState(
                            key: const ValueKey('link'),
                            fg: fg,
                            subtle: subtle,
                            urlController: _urlController,
                            nameController: _nameController,
                            nameFocus: _nameFocus,
                            urlFocus: _urlFocus,
                            selectedType: _linkType,
                            onTypeSelected: (type) =>
                                setState(() => _linkType = type),
                            serviceAccountEmail: displayEmail,
                            isLinking: _isLinking,
                            onLinkTap: _linkDocument,
                          ),
                  ),
                ],
              );
            }(),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Picker state ─────────────────────────────────────────────────────────────

class _PickerState extends StatelessWidget {
  final Color fg;
  final Color subtle;
  final FileType? selectedType;
  final ValueChanged<FileType> onTypeSelected;

  const _PickerState({
    super.key,
    required this.fg,
    required this.subtle,
    required this.selectedType,
    required this.onTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: NoSusTheme.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ADD TO GROUP',
            style: TextStyle(
              color: subtle,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Secure Upload',
            style: TextStyle(
              color: fg,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 24),

          // Dashed drop zone
          Container(
            width: double.infinity,
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: fg.withValues(alpha: 0.15),
                width: 1,
                strokeAlign: BorderSide.strokeAlignCenter,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 28,
                    color: fg.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Select a file type below',
                    style: TextStyle(
                      fontSize: 13,
                      color: fg.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // File type selector
          Row(
            children: FileType.values
                .map(
                  (type) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: type == FileType.scan ? 0 : 10,
                      ),
                      child: _TypeButton(
                        type: type,
                        fg: fg,
                        subtle: subtle,
                        onTap: () => onTypeSelected(type),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final FileType type;
  final Color fg;
  final Color subtle;
  final VoidCallback onTap;

  const _TypeButton({
    required this.type,
    required this.fg,
    required this.subtle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      FileType.pdf => Icons.picture_as_pdf_outlined,
      FileType.image => Icons.image_outlined,
      FileType.markdown => Icons.article_outlined,
      FileType.scan => Icons.document_scanner_outlined,
    };

    return Semantics(
      button: true,
      label: 'Upload ${type.label}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: fg.withValues(alpha: 0.12), width: 0.75),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(height: 5),
              Text(
                type.label,
                style: TextStyle(
                  fontSize: 9,
                  color: subtle,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Processing state ─────────────────────────────────────────────────────────

class _ProcessingState extends StatelessWidget {
  final String fileName;
  final double progress;
  final Color fg;
  final Color subtle;
  final VoidCallback onCancel;

  const _ProcessingState({
    super.key,
    required this.fileName,
    required this.progress,
    required this.fg,
    required this.subtle,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: NoSusTheme.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PREPARING & UPLOADING',
            style: TextStyle(
              color: subtle,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),

          const Center(
            child: MascotView(character: MascotCharacter.lux, size: 32),
          ),
          const SizedBox(height: 12),

          // Progress track
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: fg.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(fg),
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Uploading to secure database...',
                style: TextStyle(fontSize: 11, color: subtle),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 11,
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.close, size: 14, color: Colors.redAccent),
              label: const Text(
                'CANCEL UPLOAD',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                  letterSpacing: 1.0,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Complete state ───────────────────────────────────────────────────────────

class _CompleteState extends StatelessWidget {
  final Animation<double> checkProgress;
  final Color fg;

  const _CompleteState({
    super.key,
    required this.checkProgress,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: NoSusTheme.s24),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: checkProgress,
            builder: (context, child) => CustomPaint(
              size: const Size(56, 56),
              painter: _CheckPainter(progress: checkProgress.value, color: fg),
            ),
          ),
          const SizedBox(height: 8),
          const MascotView(character: MascotCharacter.lux, size: 28),
          const SizedBox(height: 16),
          Text(
            'Secured & Uploaded',
            style: TextStyle(
              color: fg,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 4),
          Text(
            'File added to group.',
            style: TextStyle(color: fg.withValues(alpha: 0.45), fontSize: 13),
          ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
        ],
      ),
    );
  }
}

// ─── Error state ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final Color fg;
  final VoidCallback onRetry;

  const _ErrorState({
    super.key,
    required this.message,
    required this.fg,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: NoSusTheme.s24),
      child: Column(
        children: [
          MascotView(
            character: MascotCharacter.nox,
            size: 40,
            fallback: Icon(
              Icons.error_outline,
              size: 40,
              color: Colors.red.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: fg, fontSize: 16)),
          const SizedBox(height: 16),
          Semantics(
            button: true,
            label: 'Try again',
            child: GestureDetector(
              onTap: onRetry,
              child: Text(
                'TRY AGAIN',
                style: TextStyle(
                  fontSize: 11,
                  color: fg.withValues(alpha: 0.5),
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Check mark painter ───────────────────────────────────────────────────────

class _CheckPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _CheckPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Draw circle
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2 - 2,
      paint..color = color.withValues(alpha: 0.2),
    );

    if (progress <= 0) return;

    // Draw checkmark path: starts at left, goes to center-bottom, then top-right
    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;
    path.moveTo(cx - 10, cy);
    path.lineTo(cx - 3, cy + 8);
    path.lineTo(cx + 12, cy - 8);

    final pathMetrics = path.computeMetrics().first;
    final extractedPath = pathMetrics.extractPath(
      0,
      pathMetrics.length * progress,
    );

    canvas.drawPath(extractedPath, paint..color = color);
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}

class _LinkState extends StatelessWidget {
  final Color fg;
  final Color subtle;
  final TextEditingController urlController;
  final TextEditingController nameController;
  final FocusNode nameFocus;
  final FocusNode urlFocus;
  final FileType selectedType;
  final ValueChanged<FileType> onTypeSelected;
  final String serviceAccountEmail;
  final bool isLinking;
  final VoidCallback onLinkTap;

  const _LinkState({
    super.key,
    required this.fg,
    required this.subtle,
    required this.urlController,
    required this.nameController,
    required this.nameFocus,
    required this.urlFocus,
    required this.selectedType,
    required this.onTypeSelected,
    required this.serviceAccountEmail,
    required this.isLinking,
    required this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: NoSusTheme.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LINK GOOGLE DRIVE',
            style: TextStyle(
              color: subtle,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Link Document',
            style: TextStyle(
              color: fg,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),

          // Service account card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: fg.withValues(alpha: 0.08),
                width: 0.75,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lock_person_outlined,
                      size: 16,
                      color: fg.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Secure Private Access",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: fg.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "To keep the file private, share it as 'Viewer' with this service account email in Google Drive:",
                  style: TextStyle(
                    fontSize: 11,
                    color: fg.withValues(alpha: 0.5),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: fg.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: fg.withValues(alpha: 0.08),
                            width: 0.5,
                          ),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            serviceAccountEmail,
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'Courier',
                              color: fg.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CopyButton(email: serviceAccountEmail, fg: fg),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Alternatively, make the file 'Anyone with the link can view' for instant public linking.",
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: fg.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Document Name Field
          _buildTextField(
            controller: nameController,
            focusNode: nameFocus,
            label: "Document Name",
            hint: "e.g., Lecture 4 Notes",
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => urlFocus.requestFocus(),
          ),
          const SizedBox(height: 12),

          // Drive URL Field
          _buildTextField(
            controller: urlController,
            focusNode: urlFocus,
            label: "Google Drive Link",
            hint: "https://drive.google.com/file/d/...",
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => isLinking ? null : onLinkTap(),
          ),
          const SizedBox(height: 16),

          // File Type Selector
          Text(
            "Document Type",
            style: TextStyle(
              fontSize: 11,
              color: fg.withValues(alpha: 0.5),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: FileType.values
                .map(
                  (type) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: type == FileType.scan ? 0 : 8,
                      ),
                      child: Semantics(
                        button: true,
                        selected: selectedType == type,
                        label: 'Document type ${type.label}',
                        child: GestureDetector(
                          onTap: () => onTypeSelected(type),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: selectedType == type
                                  ? fg.withValues(alpha: 0.05)
                                  : Colors.transparent,
                              border: Border.all(
                                color: selectedType == type
                                    ? fg
                                    : fg.withValues(alpha: 0.12),
                                width: 0.75,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                type.label,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: selectedType == type ? fg : subtle,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: isLinking ? null : onLinkTap,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: fg, width: 1.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: fg.withValues(alpha: isLinking ? 0.05 : 0.0),
              ),
              child: isLinking
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: fg,
                      ),
                    )
                  : Text(
                      "LINK DOCUMENT",
                      style: TextStyle(
                        color: fg,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: fg.withValues(alpha: 0.5),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: fg.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: fg.withValues(alpha: 0.1), width: 0.75),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            cursorColor: fg,
            style: TextStyle(fontSize: 13, color: fg),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 13,
                color: fg.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CopyButton extends StatefulWidget {
  final String email;
  final Color fg;

  const _CopyButton({required this.email, required this.fg});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _copied
          ? 'Service account email copied'
          : 'Copy service account email',
      child: GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: widget.email));
          HapticFeedback.lightImpact();
          setState(() => _copied = true);
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() => _copied = false);
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Service account email copied to clipboard."),
              duration: Duration(seconds: 2),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: widget.fg.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.fg.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _copied
                ? const Icon(Icons.check, size: 14, color: Colors.green)
                : Icon(Icons.copy_all_outlined, size: 14, color: widget.fg),
          ),
        ),
      ),
    );
  }
}
