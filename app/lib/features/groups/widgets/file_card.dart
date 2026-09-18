import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/group_file.dart';
import '../../../theme.dart';

/// Horizontal file card showing type icon, name, uploader, size, and security badges.
/// Supports swipe-right (delete) and swipe-left (pin) reveal actions.
class FileCard extends StatefulWidget {
  final GroupFile file;
  final VoidCallback? onDelete;
  final VoidCallback? onPin;
  final VoidCallback? onOpen;
  final String uploaderName;
  final int animationIndex;

  final VoidCallback? onRename;
  final VoidCallback? onShare;
  final VoidCallback? onAnalytics;

  const FileCard({
    super.key,
    required this.file,
    this.onDelete,
    this.onPin,
    this.onOpen,
    this.onRename,
    this.onShare,
    this.onAnalytics,
    required this.uploaderName,
    this.animationIndex = 0,
  });

  @override
  State<FileCard> createState() => _FileCardState();
}

class _FileCardState extends State<FileCard> {
  double _swipeOffset = 0;

  static const _revealThreshold = 64.0;
  static const _actionWidth = 96.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subtle = isDark
        ? NoSusTheme.dTextSecondary
        : NoSusTheme.lTextSecondary;

    return GestureDetector(
          onHorizontalDragUpdate: (d) {
            setState(() {
              _swipeOffset = (_swipeOffset + d.delta.dx).clamp(
                -_actionWidth,
                _actionWidth,
              );
            });
          },
          onHorizontalDragEnd: (_) {
            if (_swipeOffset > _revealThreshold) {
              // Swipe right → delete action
              widget.onDelete?.call();
            } else if (_swipeOffset < -_revealThreshold) {
              // Swipe left → pin action
              widget.onPin?.call();
            }
            setState(() => _swipeOffset = 0);
          },
          child: ClipRect(
            child: Stack(
              children: [
                // ── Action backgrounds ─────────────────────────────────────────
                if (_swipeOffset > 0)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: _swipeOffset.abs(),
                        color: Colors.red.withValues(alpha: 0.12),
                        child: const Center(
                          child: Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_swipeOffset < 0)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: _swipeOffset.abs(),
                        color: Colors.amber.withValues(alpha: 0.10),
                        child: const Center(
                          child: Icon(
                            Icons.push_pin_outlined,
                            color: Colors.amber,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── Card content ───────────────────────────────────────────────
                Transform.translate(
                  offset: Offset(_swipeOffset, 0),
                  child: Container(
                    padding: const EdgeInsets.all(NoSusTheme.s16),
                    decoration: NoSusTheme.cardDecoration(context),
                    child: Row(
                      children: [
                        // File type icon block
                        _FileTypeIcon(type: widget.file.type),
                        const SizedBox(width: NoSusTheme.s16),

                        // File info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (widget.file.isPinned) ...[
                                    Icon(
                                      Icons.push_pin,
                                      size: 11,
                                      color: subtle,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Expanded(
                                    child: Text(
                                      widget.file.name,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${widget.uploaderName}  ·  ${widget.file.uploadedAtLabel}  ·  ${widget.file.sizeLabel}',
                                style: TextStyle(fontSize: 11, color: subtle),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 10,
                                runSpacing: 4,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Security status dot
                                      _SecurityDot(
                                        status: widget.file.securityStatus,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        widget.file.securityStatus ==
                                                FileSecurityStatus.secured
                                            ? 'READY'
                                            : 'PROCESSING',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: subtle,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (widget.file.isWatermarked)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.water_drop_outlined,
                                          size: 10,
                                          color: subtle,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          'WATERMARKED',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: subtle,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Open button
                        const SizedBox(width: NoSusTheme.s12),
                        Semantics(
                          button: true,
                          label: 'Open ${widget.file.name}',
                          child: InkWell(
                            onTap: widget.onOpen,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: theme.colorScheme.outline,
                                  width: 0.75,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.open_in_new_rounded,
                                size: 14,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),

                        // Options Popup Menu
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          tooltip: 'More options for ${widget.file.name}',
                          icon: Icon(
                            Icons.more_vert,
                            size: 18,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          padding: EdgeInsets.zero,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(40, 40),
                            padding: EdgeInsets.zero,
                          ),
                          onSelected: (val) {
                            if (val == 'open') {
                              widget.onOpen?.call();
                            } else if (val == 'pin') {
                              widget.onPin?.call();
                            } else if (val == 'rename') {
                              widget.onRename?.call();
                            } else if (val == 'share') {
                              widget.onShare?.call();
                            } else if (val == 'analytics') {
                              widget.onAnalytics?.call();
                            } else if (val == 'delete') {
                              widget.onDelete?.call();
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'open',
                              child: Row(
                                children: [
                                  Icon(Icons.open_in_new_rounded, size: 14, color: theme.colorScheme.onSurface),
                                  const SizedBox(width: 8),
                                  const Text('Open Document', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'pin',
                              child: Row(
                                children: [
                                  Icon(
                                    widget.file.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                    size: 14,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.file.isPinned ? 'Unpin Document' : 'Pin Document',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'rename',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 14, color: theme.colorScheme.onSurface),
                                  const SizedBox(width: 8),
                                  const Text('Rename Document', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                               value: 'share',
                               child: Row(
                                 children: [
                                   Icon(Icons.ios_share_rounded, size: 14, color: theme.colorScheme.onSurface),
                                   const SizedBox(width: 8),
                                   const Text('Share Link', style: TextStyle(fontSize: 12)),
                                 ],
                               ),
                             ),
                             PopupMenuItem(
                               value: 'analytics',
                               child: Row(
                                 children: [
                                   Icon(Icons.bar_chart_rounded, size: 14, color: theme.colorScheme.onSurface),
                                   const SizedBox(width: 8),
                                   const Text('Link Analytics', style: TextStyle(fontSize: 12)),
                                 ],
                               ),
                             ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
                                  SizedBox(width: 8),
                                  Text(
                                    'Delete Document',
                                    style: TextStyle(fontSize: 12, color: Colors.redAccent),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .animate(delay: (widget.animationIndex.clamp(0, 10) * 50).ms)
        .fadeIn(duration: 250.ms)
        .slideX(begin: 0.03, end: 0, duration: 250.ms, curve: Curves.easeOut);
  }
}

// ─── File type icon ───────────────────────────────────────────────────────────

class _FileTypeIcon extends StatelessWidget {
  final FileType type;
  const _FileTypeIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;
    final subtle = isDark
        ? NoSusTheme.dTextSecondary
        : NoSusTheme.lTextSecondary;

    final icon = switch (type) {
      FileType.pdf => Icons.picture_as_pdf_outlined,
      FileType.image => Icons.image_outlined,
      FileType.markdown => Icons.article_outlined,
      FileType.scan => Icons.document_scanner_outlined,
    };

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withValues(alpha: 0.1), width: 0.75),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(height: 2),
          Text(
            type.label,
            style: TextStyle(
              fontSize: 7,
              color: subtle,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Security status dot ──────────────────────────────────────────────────────

class _SecurityDot extends StatelessWidget {
  final FileSecurityStatus status;
  const _SecurityDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      FileSecurityStatus.secured => const Color(0xFF4CAF50),
      FileSecurityStatus.processing => Colors.amber,
      FileSecurityStatus.pending => Colors.grey,
    };
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
