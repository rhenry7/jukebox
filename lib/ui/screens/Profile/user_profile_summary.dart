import 'package:flutter/material.dart';
import 'package:flutter_test_project/models/user_models.dart';
import 'package:flutter_test_project/services/user_services.dart';
import 'package:ionicons/ionicons.dart';

class UserProfileSummary extends StatefulWidget {
  const UserProfileSummary({
    super.key,
    this.color = const Color(0xFF2DBD3A),
    this.child,
  });

  final Color color;
  final Widget? child;

  @override
  State<UserProfileSummary> createState() => _UserProfileSummaryState();
}

class _UserProfileSummaryState extends State<UserProfileSummary> {
  late final Future<UserReviewInfo> userReviewInfo;

  @override
  void initState() {
    // TODO: implement initState
    userReviewInfo = UserServices().fetchCurrentUserInfo();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
          child: FutureBuilder<UserReviewInfo>(
              future: userReviewInfo,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final UserReviewInfo? userInfo = snapshot.data;
                  print(snapshot.data?.displayName);
                  if (userInfo == null) {
                    return const Center(child: Text("no data from user info"));
                  }
                  return Padding(
                    padding: EdgeInsets.only(top: 100.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // BACK BUTTON
                        const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BackButton(),
                          ],
                        ),
                        // CARD CONTENT
                        Padding(
                            padding: EdgeInsets.only(top: 10.0),
                            child: Card(
                              child: SizedBox(
                                child: SizedBox(
                                    width: 400,
                                    height: 200,
                                    child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Card(
                                              color: Colors.grey[800],
                                              child: Row(
                                                children: [
                                                  const Padding(
                                                    padding:
                                                        EdgeInsets.all(10.0),
                                                    child: Center(
                                                        child: SizedBox(
                                                      width: 100,
                                                      height: 100,
                                                      child: Card(
                                                        color: Colors.black26,
                                                        child: Icon(
                                                          Ionicons
                                                              .person_circle_outline,
                                                          color: Colors.white,
                                                          size: 50.0,
                                                          semanticLabel:
                                                              'Text to announce in accessibility modes',
                                                        ),
                                                      ),
                                                    )),
                                                  ),
                                                  Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      Padding(
                                                          padding:
                                                              EdgeInsets.all(
                                                                  8.0),
                                                          child: Center(
                                                            child: SizedBox(
                                                              width: 200,
                                                              child: Text(
                                                                userInfo
                                                                    .displayName,
                                                                style:
                                                                    const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 28,
                                                                ),
                                                                textAlign:
                                                                    TextAlign
                                                                        .left,
                                                                softWrap: true,
                                                                maxLines: 8,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis, // this bound is important !!
                                                              ),
                                                            ),
                                                          )),
                                                      Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  left: 8.0,
                                                                  right: 8.0),
                                                          child: Center(
                                                            child: SizedBox(
                                                              width: 200,
                                                              child: Text(
                                                                "You already have ${userInfo.reviewsCount.toString()} reviews!",
                                                                style: TextStyle(
                                                                    color: Colors
                                                                            .grey[
                                                                        300]),
                                                                textAlign:
                                                                    TextAlign
                                                                        .left,
                                                                softWrap: true,
                                                                maxLines: 8,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis, // this bound is important !!
                                                              ),
                                                            ),
                                                          )),
                                                      Padding(
                                                          padding:
                                                              EdgeInsets.only(
                                                                  left: 8.0,
                                                                  right: 8.0),
                                                          child: Center(
                                                            child: SizedBox(
                                                              width: 200,
                                                              child: Text(
                                                                "juxeboxxn since ${userInfo.joinDate?.year.toString()}",
                                                                style: TextStyle(
                                                                    color: Colors
                                                                            .grey[
                                                                        300]),
                                                                textAlign:
                                                                    TextAlign
                                                                        .left,
                                                                softWrap: true,
                                                                maxLines: 8,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis, // this bound is important !!
                                                              ),
                                                            ),
                                                          ))
                                                    ],
                                                  ),
                                                ],
                                              )),
                                        ])),
                              ),
                            ))
                      ],
                    ),
                  );
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              })),
    );
  }
}
