import 'package:flutter/material.dart';

import '../../../../theme.dart';

/// Orange "testnet" strip across the top of the Canary web app.
class CanaryStrip extends StatelessWidget {
  const CanaryStrip({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Material(
        color: CanaryTokens.canary,
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: CanaryTokens.text, width: 2),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: const SafeArea(
            bottom: false,
            child: Text(
              'NO SUS  ·  MONAD TESTNET  ·  USE HARMLESS TEST NOTES ONLY',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: CanaryTokens.monoFont,
                fontSize: 20,
                letterSpacing: 1,
                color: CanaryTokens.text,
              ),
            ),
          ),
        ),
      ),
      Expanded(child: child),
    ],
  );
}
