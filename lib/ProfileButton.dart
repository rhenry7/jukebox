import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

class ProfileButton extends StatelessWidget {
  final String name;
  final IoniconsData icon;
  const ProfileButton({super.key, required this.name, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.all(10.0),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Icon(icon),
                Padding(
                  padding: const EdgeInsets.only(left: 18.0),
                  child: Text(name),
                )
              ],
            ),
          ),
          ElevatedButton.icon(
              onPressed: () => print("buttonPressed"),
              icon: const Icon(Ionicons.arrow_forward_circle_outline,
                  color: Colors.white),
              label: const Text("", style: TextStyle(color: Colors.white))),
        ]));
  }
}
