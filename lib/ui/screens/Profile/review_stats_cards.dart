import 'package:flutter/material.dart';
import 'package:flutter_test_project/models/review.dart';

class ReviewStatsCards extends StatelessWidget {
  final List<Review> reviews;

  const ReviewStatsCards({super.key, required this.reviews});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month);
    final lastMonthStart = DateTime(now.year, now.month - 1);

    // This month's reviews
    final thisMonthReviews = reviews.where((r) {
      if (r.date == null) return false;
      return r.date!.isAfter(thisMonthStart.subtract(const Duration(days: 1)));
    }).length;

    // Last month's reviews
    final lastMonthReviews = reviews.where((r) {
      if (r.date == null) return false;
      return r.date!.isAfter(lastMonthStart.subtract(const Duration(days: 1))) &&
          r.date!.isBefore(thisMonthStart);
    }).length;

    // Percentage change
    final double pctChange = lastMonthReviews > 0
        ? ((thisMonthReviews - lastMonthReviews) / lastMonthReviews) * 100
        : (thisMonthReviews > 0 ? 100.0 : 0.0);

    // Average score
    final double avgScore = reviews.isNotEmpty
        ? reviews.map((r) => r.score).reduce((a, b) => a + b) / reviews.length
        : 0.0;

    // Current streak
    final streak = _calculateStreak(reviews);

    // Top genres this month
    final genreCounts = <String, int>{};
    for (final r in reviews) {
      if (r.date == null) continue;
      if (r.date!.isBefore(thisMonthStart)) continue;
      if (r.genres != null) {
        for (final g in r.genres!) {
          genreCounts[g] = (genreCounts[g] ?? 0) + 1;
        }
      }
    }
    final topGenres = (genreCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(5)
        .map((e) => e.key)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Two stat cards side by side
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'This Month',
                value: thisMonthReviews.toString(),
                subtitle: _changeText(pctChange, lastMonthReviews),
                subtitleColor:
                    pctChange >= 0 ? Colors.greenAccent : Colors.redAccent,
                icon: pctChange >= 0
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                iconColor:
                    pctChange >= 0 ? Colors.greenAccent : Colors.redAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: 'Average Score',
                value: avgScore.toStringAsFixed(1),
                subtitle: 'across all reviews',
                subtitleColor: Colors.white54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Streak card
        _StatCard(
          title: 'Current Streak',
          value: '$streak day${streak == 1 ? '' : 's'}',
          subtitle: 'consecutive days with reviews',
          subtitleColor: Colors.white54,
          icon: Icons.local_fire_department,
          iconColor: streak > 0 ? Colors.orangeAccent : Colors.white24,
        ),
        // Top genres pills
        if (topGenres.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: topGenres.map((genre) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.green.withOpacity(0.4), width: 1),
                ),
                child: Text(
                  genre,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  String _changeText(double pct, int lastMonth) {
    if (lastMonth == 0) return 'no reviews last month';
    final sign = pct >= 0 ? '+' : '';
    return '$sign${pct.round()}% vs last month';
  }

  int _calculateStreak(List<Review> reviews) {
    final reviewDates = <DateTime>{};
    for (final r in reviews) {
      if (r.date == null) continue;
      final d = r.date!;
      reviewDates.add(DateTime(d.year, d.month, d.day));
    }

    var streak = 0;
    var current = DateTime.now();
    current = DateTime(current.year, current.month, current.day);

    while (reviewDates.contains(current)) {
      streak++;
      current = current.subtract(const Duration(days: 1));
    }
    return streak;
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color subtitleColor;
  final IconData? icon;
  final Color? iconColor;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.subtitleColor,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                if (icon != null)
                  Icon(icon, color: iconColor ?? Colors.white24, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: subtitleColor, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
