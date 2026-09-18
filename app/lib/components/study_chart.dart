import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../features/focus/providers/focus_provider.dart';

class StudyChart extends ConsumerStatefulWidget {
  const StudyChart({super.key});

  @override
  ConsumerState<StudyChart> createState() => _StudyChartState();
}

class _StudyChartState extends ConsumerState<StudyChart> {
  int _selectedDayIndex = 6; // Default to Friday/Today (last element)

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final timelineAsync = ref.watch(studyTimelineProvider);

    return timelineAsync.when(
      data: (data) {
        if (data.isEmpty) {
          return const Center(child: Text("No focus data"));
        }

        // Find max hours to scale bars
        double maxHours = data
            .map((d) => d.hours)
            .fold(1.0, (max, val) => val > max ? val : max);
        if (maxHours < 1.0) maxHours = 1.0;

        // Ensure selected index is within bounds
        if (_selectedDayIndex >= data.length) {
          _selectedDayIndex = data.length - 1;
        }

        final selectedData = data[_selectedDayIndex];

        return Container(
          padding: const EdgeInsets.all(NoSusTheme.s24),
          decoration: NoSusTheme.cardDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FOCUS TIMELINE',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: NoSusTheme.s4),
                      Text(
                        '${selectedData.hours}h Focused',
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: NoSusTheme.s12,
                      vertical: NoSusTheme.s8,
                    ),
                    decoration: NoSusTheme.buttonDecoration(
                      context,
                      radius: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                        const SizedBox(width: NoSusTheme.s4),
                        Text(
                          '${selectedData.scans} Checks',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NoSusTheme.s32),
              // Chart Graphic
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(data.length, (index) {
                    final dayData = data[index];
                    final isSelected = index == _selectedDayIndex;
                    final percentage = dayData.hours / maxHours;

                    return Expanded(
                      child: Semantics(
                        button: true,
                        selected: isSelected,
                        label:
                            '${dayData.day}: ${dayData.hours.toStringAsFixed(1)} hours',
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedDayIndex = index;
                            });
                          },
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final barHeight =
                                          constraints.maxHeight * percentage;
                                      return Stack(
                                        alignment: Alignment.bottomCenter,
                                        children: [
                                          // Base track guide line
                                          Positioned(
                                            top: 0,
                                            bottom: 0,
                                            child: Container(
                                              width: 1,
                                              color: theme.colorScheme.outline
                                                  .withValues(alpha: 0.1),
                                            ),
                                          ),
                                          // Animated Bar
                                          AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            curve: Curves.fastOutSlowIn,
                                            width: 28,
                                            height: barHeight.clamp(
                                              4.0,
                                              double.infinity,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? theme.colorScheme.onSurface
                                                  : (isDark
                                                        ? Colors.white
                                                              .withValues(
                                                                alpha: 0.08,
                                                              )
                                                        : Colors.black
                                                              .withValues(
                                                                alpha: 0.04,
                                                              )),
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                    top: Radius.circular(6),
                                                  ),
                                              border: Border.all(
                                                color: isSelected
                                                    ? theme
                                                          .colorScheme
                                                          .onSurface
                                                    : theme.colorScheme.outline,
                                                width: 1.2,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: NoSusTheme.s12),
                                Text(
                                  dayData.day,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? theme.colorScheme.onSurface
                                        : theme.colorScheme.onSurface
                                              .withValues(alpha: 0.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.all(NoSusTheme.s24),
        decoration: NoSusTheme.cardDecoration(context),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.grey),
        ),
      ),
      error: (err, stack) => Container(
        padding: const EdgeInsets.all(NoSusTheme.s24),
        decoration: NoSusTheme.cardDecoration(context),
        child: Center(
          child: Text(
            'Error loading timeline: $err',
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      ),
    );
  }
}

class StudyDayData {
  final String day;
  final double hours;
  final int scans;

  StudyDayData({required this.day, required this.hours, required this.scans});
}
