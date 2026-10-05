import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../models/checkin.dart';

/// The person sees their own mood answers over two weeks, never a risk score.
/// Missing days are simply gaps: no streaks, no "you missed a day".
class MoodJourney extends StatelessWidget {
  const MoodJourney({super.key, required this.checkIns});
  final List<CheckIn> checkIns;

  static const days = 14;

  @override
  Widget build(BuildContext context) {
    final today = startOfDay(DateTime.now());
    final byDay = <int, int>{};
    for (final c in checkIns) {
      if (c.mood == null) continue;
      final age = calendarDaysBetween(c.at, today);
      if (age >= 0 && age < days) byDay[age] = c.mood!;
    }
    final scheme = Theme.of(context).colorScheme;
    final answered = byDay.length;
    const words = {1: 'very low', 2: 'low', 3: 'okay', 4: 'good', 5: 'very good'};
    final latest = byDay.isEmpty ? null : byDay[byDay.keys.reduce((a, b) => a < b ? a : b)];

    return Semantics(
      label: answered == 0
          ? 'No mood answers in the last two weeks yet.'
          : 'Mood over the last two weeks. $answered days answered. Most recent: ${words[latest]}.',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 120,
              width: double.infinity,
              child: CustomPaint(
                painter: _JourneyPainter(
                  byDay: byDay,
                  line: scheme.primary,
                  grid: scheme.outlineVariant,
                  dot: scheme.surface,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(friendlyDate(today.subtract(const Duration(days: days - 1))),
                    style: Theme.of(context).textTheme.bodySmall),
                Text('Today', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyPainter extends CustomPainter {
  _JourneyPainter({required this.byDay, required this.line, required this.grid, required this.dot});
  final Map<int, int> byDay;
  final Color line;
  final Color grid;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 10.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;
    double x(int age) => pad + w * (MoodJourney.days - 1 - age) / (MoodJourney.days - 1);
    double y(int mood) => pad + h * (5 - mood) / 4;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final m in [1, 3, 5]) {
      canvas.drawLine(Offset(pad, y(m)), Offset(size.width - pad, y(m)), gridPaint);
    }

    final linePaint = Paint()
      ..color = line
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Connect consecutive answered days only; gaps stay gaps.
    for (var age = MoodJourney.days - 1; age > 0; age--) {
      final a = byDay[age];
      final b = byDay[age - 1];
      if (a != null && b != null) {
        canvas.drawLine(Offset(x(age), y(a)), Offset(x(age - 1), y(b)), linePaint);
      }
    }
    final fill = Paint()..color = dot;
    byDay.forEach((age, mood) {
      final c = Offset(x(age), y(mood));
      canvas.drawCircle(c, 6, fill);
      canvas.drawCircle(c, 6, linePaint..strokeWidth = 2.5);
    });
  }

  @override
  bool shouldRepaint(covariant _JourneyPainter old) => old.byDay != byDay || old.line != line;
}
