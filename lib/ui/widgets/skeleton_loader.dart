import 'package:flutter/material.dart';

class SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: borderRadius ?? BorderRadius.circular(4),
      ),
    );
  }
}

class ReviewCardSkeleton extends StatelessWidget {
  const ReviewCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Card(
        color: Colors.black,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Album cover skeleton
              SkeletonLoader(
                width: 80,
                height: 80,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(width: 16),
              // Text skeletons
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLoader(width: double.infinity, height: 20),
                    SizedBox(height: 8),
                    SkeletonLoader(width: 150, height: 16),
                    SizedBox(height: 12),
                    SkeletonLoader(width: 100, height: 16),
                    SizedBox(height: 12),
                    SkeletonLoader(width: double.infinity, height: 14),
                    SizedBox(height: 4),
                    SkeletonLoader(width: double.infinity, height: 14),
                    SizedBox(height: 4),
                    SkeletonLoader(width: 200, height: 14),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecommendationCardSkeleton extends StatelessWidget {
  const RecommendationCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white10,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            SkeletonLoader(
              width: 60,
              height: 60,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(width: double.infinity, height: 14),
                  SizedBox(height: 8),
                  SkeletonLoader(width: 120, height: 12),
                  SizedBox(height: 8),
                  SkeletonLoader(width: 100, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
