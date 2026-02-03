import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_test_project/models/review.dart';
import 'package:flutter_test_project/models/enhanced_user_preferences.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';
import 'package:flutter_test_project/providers/preferences_provider.dart';
import 'package:flutter_test_project/providers/music_profile_insights_provider.dart';
import 'package:flutter_test_project/services/music_profile_insights_service.dart';

/// Dashboard widget showing analytics charts for user reviews and preferences
class ProfileAnalyticsDashboard extends ConsumerWidget {
  const ProfileAnalyticsDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(userReviewsProvider);
    final preferencesAsync = ref.watch(userPreferencesStreamProvider);
    final insightsAsync = ref.watch(musicProfileInsightsAutoProvider);

    return reviewsAsync.when(
      data: (reviewsWithDocIds) {
        final reviews = reviewsWithDocIds.map((r) => r.review).toList();
        return preferencesAsync.when(
          data: (preferences) {
            return insightsAsync.when(
              data: (insights) {
                return _AnalyticsContent(
                  reviews: reviews,
                  preferences: preferences,
                  insights: insights,
                );
              },
              loading: () => _AnalyticsContent(
                reviews: reviews,
                preferences: preferences,
              ),
              error: (_, __) => _AnalyticsContent(
                reviews: reviews,
                preferences: preferences,
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _AnalyticsContent(reviews: reviews),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(
        child: Text(
          'Error loading analytics',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

class _AnalyticsContent extends StatelessWidget {
  final List<Review> reviews;
  final EnhancedUserPreferences? preferences;
  final MusicProfileInsights? insights;

  const _AnalyticsContent({
    required this.reviews,
    this.preferences,
    this.insights,
  });

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No data to display',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              SizedBox(height: 8),
              Text(
                'Start reviewing music to see your analytics!',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Insights Summary Card
          if (insights != null) ...[
            _InsightsSummaryCard(insights: insights!),
            const SizedBox(height: 16),
          ],

          // Review Score Over Time Chart
          _ReviewScoreChartCard(reviews: reviews),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Chart card showing review scores over time
class _ReviewScoreChartCard extends StatelessWidget {
  final List<Review> reviews;

  const _ReviewScoreChartCard({required this.reviews});

  @override
  Widget build(BuildContext context) {
    // Group reviews by month
    final Map<String, double> monthlyAverages = {};
    final Map<String, int> monthlyCounts = {};

    for (final review in reviews) {
      if (review.date != null) {
        final monthKey = DateFormat('MMM yyyy').format(review.date!);
        monthlyAverages[monthKey] =
            (monthlyAverages[monthKey] ?? 0) + review.score;
        monthlyCounts[monthKey] = (monthlyCounts[monthKey] ?? 0) + 1;
      }
    }

    // Calculate averages
    monthlyAverages.forEach((key, value) {
      monthlyAverages[key] = value / monthlyCounts[key]!;
    });

    final sortedMonths = monthlyAverages.keys.toList()
      ..sort((a, b) => DateFormat('MMM yyyy')
          .parse(a)
          .compareTo(DateFormat('MMM yyyy').parse(b)));

    final spots = sortedMonths.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), monthlyAverages[entry.value]!);
    }).toList();

    final avgScore =
        reviews.map((r) => r.score).reduce((a, b) => a + b) / reviews.length;

    return _ChartCard(
      title: 'Review Score Trend',
      value: avgScore.toStringAsFixed(1),
      subtitle: 'Average rating',
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.white.withOpacity(0.1),
                  strokeWidth: 1,
                );
              },
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) {
                    if (value.toInt() >= 0 &&
                        value.toInt() < sortedMonths.length) {
                      final month = sortedMonths[value.toInt()];
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          month.split(' ')[0], // Just month abbreviation
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: Colors.red[600],
                barWidth: 3,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 4,
                      color: Colors.red[600]!,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.red[600]!.withOpacity(0.2),
                ),
              ),
            ],
            minY: 0,
            maxY: 5,
          ),
        ),
      ),
    );
  }
}

/// Insights summary card showing key profile data
class _InsightsSummaryCard extends StatelessWidget {
  final MusicProfileInsights insights;

  const _InsightsSummaryCard({required this.insights});

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
                const Text(
                  'Music Profile Insights',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  Icons.insights,
                  color: Colors.red[600],
                  size: 28,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Favorite Artists
            if (insights.favoriteArtists.isNotEmpty) ...[
              _InsightRow(
                label: 'Favorite Artists',
                value: insights.favoriteArtists.length.toString(),
                items: insights.favoriteArtists.take(5).toList(),
                icon: Icons.person,
                color: Colors.red[600]!,
              ),
              const SizedBox(height: 16),
            ],
            // Favorite Genres
            if (insights.favoriteGenres.isNotEmpty) ...[
              _InsightRow(
                label: 'Favorite Genres',
                value: insights.favoriteGenres.length.toString(),
                items: insights.favoriteGenres.take(5).toList(),
                icon: Icons.music_note,
                color: Colors.green[600]!,
              ),
              const SizedBox(height: 16),
            ],
            // Most Common Album
            if (insights.mostCommonAlbum != null) ...[
              Row(
                children: [
                  Icon(Icons.album, color: Colors.grey[400], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Most Reviewed',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          insights.mostCommonAlbum!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Insight row widget
class _InsightRow extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final IconData icon;
  final Color color;

  const _InsightRow({
    required this.label,
    required this.value,
    required this.items,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: items.map((item) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: color.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Reusable chart card container
class _ChartCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.child,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        value,
                        style: TextStyle(
                          color: Colors.red[600],
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.bar_chart,
                  color: Colors.white.withOpacity(0.3),
                  size: 32,
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
