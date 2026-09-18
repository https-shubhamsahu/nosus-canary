import 'package:flutter/material.dart';

/// The brief, branded hold shown only while auth state is actually resolving.
///
/// Startup work begins before this widget is built; it never adds a timer,
/// request, or minimum duration of its own. The square stop is the sole motion so
/// the canonical wordmark remains the visual focus.
class BrandSplash extends StatefulWidget {
  const BrandSplash({super.key});

  @override
  State<BrandSplash> createState() => _BrandSplashState();
}

class _BrandSplashState extends State<BrandSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _stopController;
  bool _motionConfigured = false;

  @override
  void initState() {
    super.initState();
    _stopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motionConfigured) return;
    _motionConfigured = true;

    if (MediaQuery.disableAnimationsOf(context)) {
      _stopController.value = 1;
    } else {
      _stopController.forward();
    }
  }

  @override
  void dispose() {
    _stopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final fontSize = constraints.maxWidth < 360 ? 34.0 : 42.0;

            return Center(
              child: Semantics(
                container: true,
                liveRegion: true,
                label: 'NO SUS opening application',
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      letterSpacing: -0.5,
                    ),
                    children: [
                      const TextSpan(text: 'NO SUS'),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: FadeTransition(
                          opacity: CurvedAnimation(
                            parent: _stopController,
                            curve: Curves.easeOut,
                          ),
                          child: Transform.translate(
                            offset: const Offset(0, -1),
                            child: Container(
                              key: const ValueKey('brand-square-stop'),
                              width: fontSize * 0.21,
                              height: fontSize * 0.21,
                              margin: EdgeInsets.only(
                                left: fontSize * 0.08,
                                bottom: fontSize * 0.02,
                              ),
                              color: const Color(0xFF808080),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
