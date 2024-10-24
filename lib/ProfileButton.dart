import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

class ProfileButton extends StatelessWidget {
  final String name;
  final IoniconsData icon;
  const ProfileButton({super.key, required this.name, required this.icon});

  @override
  Widget build(BuildContext context) {
    Color useColor = name == 'LogOut' ? Colors.red : Colors.white;
    return Padding(
        padding: EdgeInsets.all(8.0),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Icon(
                  icon,
                  color: useColor,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(name),
                )
              ],
            ),
          ),
          name != 'LogOut'
              ? IconButton(
                  onPressed: (() => {}),
                  icon: const Icon(Ionicons.chevron_forward_outline))
              : const Text(""),
        ]));
  }
}
