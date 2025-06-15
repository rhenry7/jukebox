import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' as flutter;
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_test_project/apis.dart';
import 'package:gap/gap.dart';
import 'package:spotify/spotify.dart';

class DiscoBallLoading extends StatelessWidget {
  const DiscoBallLoading({super.key});
  @override
  Widget build(BuildContext context) {
    return  Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          flutter.Image.asset('lib/assets/images/discoball_loading.png'),
          const SizedBox(height: 16),
          const Text('One sec...', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
