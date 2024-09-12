import 'package:flutter/material.dart';
import 'package:flutter_test_project/Types/userComments.dart';
import 'package:flutter_test_project/apis.dart';
import 'package:gap/gap.dart';

class SubCommentThread extends StatefulWidget {
  const SubCommentThread({super.key});
  @override
  SubCommentThreadState createState() => SubCommentThreadState();
}

class SubCommentThreadState extends State<SubCommentThread> {
  late Future<List<UserComment>> comments;

  @override
  void initState() {
    super.initState();
    comments = fetchMockUserComments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.only(left: 2, top: 10),
        child: Column(
          children: [
            Expanded(
                child: SingleChildScrollView(
                    child: Column(
              children: [
                FutureBuilder(
                    future: comments,
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return ListView.builder(
                          itemCount: snapshot.data!.length,
                          itemBuilder: (context, index) {
                            final post = snapshot.data![index];
                            return Text(
                              post.comment,
                              style: TextStyle(color: Colors.white),
                            );
                          },
                        );
                      } else if (snapshot.hasError) {
                        return Text('Error ${snapshot.error}');
                      }
                      return const CircularProgressIndicator();
                    })
              ],
            ))),
          ],
        ),
      ),
    );
  }
}
