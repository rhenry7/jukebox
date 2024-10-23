import 'package:flutter/material.dart';

class TagInputScreen extends StatefulWidget {
  const TagInputScreen({super.key});

  @override
  _TagInputScreenState createState() => _TagInputScreenState();
}

class _TagInputScreenState extends State<TagInputScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _tags = [];

  void _addTag() {
    String tag = _controller.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag); // Add the tag to the list
        _controller.clear(); // Clear the input field
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag); // Remove the tag from the list
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Input field to enter tags
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Enter a tag and press +',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                onPressed: _addTag,
                icon: const Icon(Icons.add),
                tooltip: 'Add tag',
              )
            ],
          ),
          const SizedBox(height: 16),
          // Horizontal scrollable tag list
          SizedBox(
            height: 50, // Height for the horizontal list
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _tags.map((tag) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Chip(
                    label: Text(tag),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    deleteIcon: const Icon(Icons.close),
                    onDeleted: () => _removeTag(tag),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
