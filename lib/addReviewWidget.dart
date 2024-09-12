import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AddReview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        child: const Text('showModalBottomSheet'),
        onPressed: () {
          showModalBottomSheet<void>(
            context: context,
            builder: (BuildContext context) {
              return Container(
                height: 200,
                padding: const EdgeInsets.all(15),
                color: Colors.blueAccent,
                child: const Column(
                  children: [
                    Icon(Icons.info_outline),
                    Text('FYI'),
                    Text('Learn more about Modal Bottom Sheet here'),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
