import 'package:flutter/material.dart';

class AddReview extends StatelessWidget {
  const AddReview({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        child: Text('showModalBottomSheet'),
        onPressed: () {
          showModalBottomSheet<void>(
            context: context,
            builder: (BuildContext context) {
              return Container(
                height: 200,
                padding: EdgeInsets.all(15),
                color: Colors.blueAccent,
                child: Column(
                  children: [
                    //Icon(Icons.info_outline),
                    // Text('FYI'),
                    Text('HELLOOOOO??!?!?!?!'),
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
