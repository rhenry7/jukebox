import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' as flutter;

class DiscoBallLoading extends StatelessWidget {
  const DiscoBallLoading({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          flutter.Image.asset('lib/assets/images/discoball_loading.png'),
          const SizedBox(height: 8),
          const Text('One sec...', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
