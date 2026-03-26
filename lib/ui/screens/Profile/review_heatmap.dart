import 'package:flutter/material.dart';
import 'package:flutter_test_project/models/review.dart';

class ReviewHeatmap extends StatelessWidget {
  final List<Review> reviews;

  const ReviewHeatmap({super.key, required this.reviews});

  static const int _weeksToShow = 26;
  static const double _cellSize = 14;
  static const double _cellGap = 3;
  static const double _dayLabelWidth = 32;

  static const List<String> _dayLabels = ['', 'Mon', '', 'Wed', '', 'Fri', ''];

  static Color _colorForCount(int count) {
    if (count == 0) return Colors.grey[850]!;
    if (count == 1) return const Color(0xFF0E4429);
    if (count == 2) return const Color(0xFF006D32);
    if (count == 3) return const Color(0xFF26A641);
    return const Color(0xFF39D353);
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, int> _buildCountMap() {
    final counts = <String, int>{};
    for (final review in reviews) {
      if (review.date == null) continue;
      final key = _dateKey(review.date!);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  /// Returns the Sunday that starts the week containing [date].
  static DateTime _startOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday % 7));
  }

  @override
  Widget build(BuildContext context) {
    final counts = _buildCountMap();
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // End of grid = end of current week (Saturday)
    final gridEnd = _startOfWeek(todayDate).add(const Duration(days: 6));
    // Start of grid = _weeksToShow weeks before gridEnd's week start
    final gridStart =
        _startOfWeek(gridEnd).subtract(const Duration(days: (_weeksToShow - 1) * 7));

    // Count reviews in the last 6 months
    final sixMonthsAgo = todayDate.subtract(const Duration(days: 182));
    final totalInRange = reviews
        .where((r) =>
            r.date != null &&
            DateTime(r.date!.year, r.date!.month, r.date!.day)
                .isAfter(sixMonthsAgo.subtract(const Duration(days: 1))))
        .length;

    // Build week columns — each column is a list of 7 days (Sun=0..Sat=6)
    final weeks = <List<DateTime>>[];
    var weekStart = gridStart;
    while (!weekStart.isAfter(gridEnd)) {
      final week = List.generate(7, (i) => weekStart.add(Duration(days: i)));
      weeks.add(week);
      weekStart = weekStart.add(const Duration(days: 7));
    }

    // Determine month labels and their column positions
    final monthLabels = <_MonthLabel>[];
    for (var i = 0; i < weeks.length; i++) {
      // Use the first day of the week to determine month
      final firstDay = weeks[i][0];
      if (i == 0 || firstDay.month != weeks[i - 1][0].month) {
        monthLabels.add(_MonthLabel(
          column: i,
          label: _monthName(firstDay.month),
        ));
      }
    }

    return Card(
      color: Colors.grey[900],
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              '$totalInRange reviews in the last 6 months',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Heatmap grid
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Month labels row
                  Row(
                    children: [
                      const SizedBox(width: _dayLabelWidth),
                      ...List.generate(weeks.length, (col) {
                        final label = monthLabels
                            .where((m) => m.column == col)
                            .firstOrNull;
                        return SizedBox(
                          width: _cellSize + _cellGap,
                          child: label != null
                              ? Text(
                                  label.label,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Grid rows (7 days)
                  ...List.generate(7, (row) {
                    return Row(
                      children: [
                        // Day label
                        SizedBox(
                          width: _dayLabelWidth,
                          height: _cellSize + _cellGap,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _dayLabels[row],
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                        // Cells for this day across all weeks
                        ...List.generate(weeks.length, (col) {
                          final date = weeks[col][row];
                          final isFuture = date.isAfter(todayDate);
                          final count = isFuture ? 0 : (counts[_dateKey(date)] ?? 0);
                          return Padding(
                            padding: const EdgeInsets.only(
                                right: _cellGap, bottom: _cellGap),
                            child: Tooltip(
                              message: isFuture
                                  ? ''
                                  : '$count review${count == 1 ? '' : 's'} on '
                                      '${date.month}/${date.day}/${date.year}',
                              child: Container(
                                width: _cellSize,
                                height: _cellSize,
                                decoration: BoxDecoration(
                                  color: isFuture
                                      ? Colors.transparent
                                      : _colorForCount(count),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'Less',
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
                const SizedBox(width: 4),
                ...List.generate(5, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Container(
                      width: _cellSize,
                      height: _cellSize,
                      decoration: BoxDecoration(
                        color: _colorForCount(i),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 4),
                const Text(
                  'More',
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _monthName(int month) {
    const names = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
    return names[month - 1];
  }
}

class _MonthLabel {
  final int column;
  final String label;
  const _MonthLabel({required this.column, required this.label});
}
