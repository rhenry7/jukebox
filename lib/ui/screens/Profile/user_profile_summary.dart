import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

class UserProfileSummary extends StatelessWidget {
  const UserProfileSummary({
    super.key,
    this.color = const Color(0xFF2DBD3A),
    this.child,
  });

  final Color color;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.only(top: 100.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BackButton(),
                ],
              ),
              Padding(
                padding: EdgeInsets.only(top: 10.0),
                child: Card(
                  child: SizedBox(
                    width: 400,
                    height: 200,
                    child: Card(
                        color: Colors.amber,
                        child: Row(
                          children: [
                            Padding(
                              padding: EdgeInsets.all(10.0),
                              child: Center(
                                child: Icon(
                                  Ionicons.location_outline,
                                  color: Colors.pink,
                                  size: 50.0,
                                  semanticLabel:
                                      'Text to announce in accessibility modes',
                                ),
                              ),
                            ),
                            Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Center(
                                  child: SizedBox(
                                    width: 200,
                                    child: Text(
                                      'By this way you will see this text break into maximum of three lines in real time. After that it will continue as ellipsis',
                                      textAlign: TextAlign.left,
                                      softWrap: true,
                                      maxLines: 8,
                                      overflow: TextOverflow
                                          .ellipsis, // this bound is important !!
                                    ),
                                  ),
                                )),
                          ],
                        )),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
