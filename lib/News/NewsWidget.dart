import 'package:flutter/material.dart';
import 'package:flutter_test_project/News/News.dart';
import 'package:url_launcher/url_launcher.dart';

/// -------- WIDGET --------
class MusicNewsWidget extends StatelessWidget {
  final List<String> filterKeywords; // ⬅️ Now a list!

  const MusicNewsWidget({Key? key, required this.filterKeywords})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MusicNewsArticle>>(
      future: NewsApiService().fetchArticles(filterKeywords),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No news articles found.'));
        }

        final articles = snapshot.data!;
        return ListView.builder(
          itemCount: articles.length,
          itemBuilder: (context, index) {
            return _NewsCard(article: articles[index]);
          },
        );
      },
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
      child: ListTile(
        onTap: () => _launchURL(context, article.url),
        leading: article.imageUrl.isNotEmpty
            ? SizedBox(
                width: 60,
                height: 60,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    article.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.broken_image),
                  ),
                ),
              )
            : const Icon(Icons.image_not_supported),
        title:
            Text(article.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(article.description,
            maxLines: 3, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
