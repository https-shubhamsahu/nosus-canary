import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SharedContent {
  final String type; // 'text', 'image', 'pdf', 'url'
  final String data; // text content, URL, or local file path
  final String? name; // file name if applicable

  const SharedContent({
    required this.type,
    required this.data,
    this.name,
  });

  factory SharedContent.fromMap(Map<String, dynamic> map) {
    return SharedContent(
      type: map['type'] as String,
      data: map['data'] as String,
      name: map['name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'data': data,
      'name': name,
    };
  }
}

class ShareIntentNotifier extends Notifier<SharedContent?> {
  static const _channel = MethodChannel('co.nosus.app/share');

  @override
  SharedContent? build() {
    _init();
    ref.onDispose(() {
      _channel.setMethodCallHandler(null);
    });
    return null;
  }

  void _init() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShareReceived') {
        if (call.arguments != null) {
          final data = Map<String, dynamic>.from(call.arguments as Map);
          state = SharedContent.fromMap(data);
        }
      }
    });

    try {
      final initial = await _channel.invokeMethod<Map>('getInitialShare');
      if (initial != null) {
        final data = Map<String, dynamic>.from(initial);
        state = SharedContent.fromMap(data);
      }
    } catch (_) {}
  }

  void clear() {
    state = null;
  }
}

final shareIntentProvider = NotifierProvider<ShareIntentNotifier, SharedContent?>(
  ShareIntentNotifier.new,
);
