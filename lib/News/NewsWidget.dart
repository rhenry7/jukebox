import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/News/News.dart';
import 'package:flutter_test_project/providers/preferences_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// -------- WIDGET --------
class MusicNewsWidget extends ConsumerWidget {
  final List<String>? filterKeywords; // Optional - if null, uses user preferences

  const MusicNewsWidget({Key? key, this.filterKeywords}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesAsync = ref.watch(userPreferencesProvider);
    
    return preferencesAsync.when(
      data: (preferences) {
        // Use personalized keywords if no filterKeywords provided
        final keywords = filterKeywords ?? 
            NewsApiService.generatePersonalizedKeywords(
              favoriteGenres: preferences.favoriteGenres,
              favoriteArtists: preferences.favoriteArtists,
            );
        
        return FutureBuilder<List<MusicNewsArticle>>(
          future: filterKeywords == null
              ? NewsApiService().fetchPersonalizedArticles(
                  favoriteGenres: preferences.favoriteGenres,
                  favoriteArtists: preferences.favoriteArtists,
                )
              : NewsApiService().fetchArticles(keywords),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.red),
              );
            } else if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading articles',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.article_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'No music articles found',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Try updating your music preferences to see personalized news',
                      style: TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            final articles = snapshot.data!;
            return RefreshIndicator(
              onRefresh: () async {
                // Trigger refresh by invalidating the provider
                ref.invalidate(userPreferencesProvider);
              },
              color: Colors.red[600],
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: articles.length,
                itemBuilder: (context, index) {
                  return _NewsCard(article: articles[index]);
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: Colors.red),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Error loading preferences',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// -------- NEWS CARD --------
class _NewsCard extends StatelessWidget {
  final MusicNewsArticle article;

  const _NewsCard({Key? key, required this.article}) : super(key: key);

  void _launchURL(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch article')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey[900],
      child: InkWell(
        onTap: () => _launchURL(context, article.url),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image (only show if available and loads successfully)
              if (article.imageUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    article.imageUrl,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: double.infinity,
                        height: 200,
                        color: Colors.grey[800],
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            color: Colors.white54,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      // Silently hide failed images - don't show error or placeholder
                      // This prevents console spam from network errors
                      return const SizedBox.shrink();
                    },
                    // Add headers to help with CORS issues
                    headers: const {
                      'User-Agent': 'Mozilla/5.0 (compatible; Jukeboxd/1.0)',
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // Title (bold, larger font)
              Text(
                article.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Description (smaller font, body copy)
              if (article.description.isNotEmpty)
                Text(
                  article.description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
