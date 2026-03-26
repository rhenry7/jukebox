import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test_project/providers/spotify_artist_provider.dart';

class GenreDistributionChart extends StatelessWidget {
  final List<TopArtistData> artists;

  const GenreDistributionChart({super.key, required this.artists});

  static const _colors = [
    Color(0xFFEF4444), // red
    Color(0xFF3B82F6), // blue
    Color(0xFF22C55E), // green
    Color(0xFFF59E0B), // amber
    Color(0xFF8B5CF6), // violet
    Color(0xFFEC4899), // pink
    Color(0xFF6B7280), // grey (for "Other")
  ];

  @override
  Widget build(BuildContext context) {
    final genreData = _computeGenres();
    if (genreData.isEmpty) return const SizedBox.shrink();

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
            const Text(
              'Genre Distribution',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  // Donut chart
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                        sections: genreData
                            .asMap()
                            .entries
                            .map((e) => PieChartSectionData(
                                  color: _colors[e.key % _colors.length],
                                  value: e.value.percentage,
                                  title: '${e.value.percentage.round()}%',
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  radius: 50,
                                  titlePositionPercentageOffset: 0.6,
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Legend
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: genreData.asMap().entries.map((e) {
                        final color = _colors[e.key % _colors.length];
                        final entry = e.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  entry.name,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${entry.percentage.round()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_GenreEntry> _computeGenres() {
    // Aggregate genres weighted by review count
    final genreCounts = <String, int>{};
    for (final artist in artists) {
      for (final genre in artist.genres) {
        genreCounts[genre] = (genreCounts[genre] ?? 0) + artist.reviewCount;
      }
    }

    if (genreCounts.isEmpty) return [];

    final sorted = genreCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = sorted.fold<int>(0, (sum, e) => sum + e.value);
    if (total == 0) return [];

    // Take top 6, group rest as "Other"
    final topEntries = sorted.take(6).toList();
    final otherSum = sorted.skip(6).fold<int>(0, (sum, e) => sum + e.value);

    final result = topEntries
        .map((e) => _GenreEntry(
              name: _capitalize(e.key),
              percentage: (e.value / total) * 100,
            ))
        .toList();

    if (otherSum > 0) {
      result.add(_GenreEntry(
        name: 'Other',
        percentage: (otherSum / total) * 100,
      ));
    }

    return result;
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

class _GenreEntry {
  final String name;
  final double percentage;
  const _GenreEntry({required this.name, required this.percentage});
}
