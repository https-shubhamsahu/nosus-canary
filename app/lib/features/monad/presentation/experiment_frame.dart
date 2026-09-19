import 'package:flutter/material.dart';

class ExperimentFrame extends StatelessWidget {
  const ExperimentFrame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Center(
              child: Text(
                'NO SUS · Monad testnet · use harmless test notes only',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
      Expanded(child: child),
    ],
  );
}
