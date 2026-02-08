import 'package:flutter/material.dart';
import 'package:flutter_test_project/utils/cached_image.dart';

/// A full-screen review text editor that matches the design language shown in
/// apps like Letterboxd.
///
/// Features:
/// - Album art + "Add Review" / "Edit Review" header with a Done button
/// - Large, distraction-free text area that fills the screen
/// - Formatting toolbar pinned above the keyboard (Bold, Italic, List, Link)
/// - Handles iOS/Android keyboard insets so the toolbar + text area never get
///   hidden behind the software keyboard.
class ReviewTextEditor extends StatefulWidget {
  /// Initial text to populate the editor with (e.g. when editing an existing review).
  final String initialText;

  /// Album / track image URL shown in the header.
  final String albumImageUrl;

  /// Title shown in the app bar ("Add Review" or "Edit Review").
  final String headerTitle;

  const ReviewTextEditor({
    super.key,
    this.initialText = '',
    this.albumImageUrl = '',
    this.headerTitle = 'Add Review',
  });

  @override
  State<ReviewTextEditor> createState() => _ReviewTextEditorState();
}

class _ReviewTextEditorState extends State<ReviewTextEditor> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late UndoHistoryController _undoController;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _focusNode = FocusNode();
    _undoController = UndoHistoryController();

    // Auto-focus the text field after the frame so the keyboard opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _undoController.dispose();
    super.dispose();
  }

  /// Return the current text to the caller and pop.
  void _onDone() {
    Navigator.of(context).pop(_controller.text);
  }

  // ─── Formatting helpers ──────────────────────────────────────

  /// Wraps the currently selected text (or inserts at cursor) with [before]
  /// and [after] markers. E.g. bold: **text**
  void _wrapSelection(String before, String after) {
    final text = _controller.text;
    final sel = _controller.selection;

    if (!sel.isValid) return;

    final selected = sel.textInside(text);
    final newText = '$before$selected$after';
    final updatedText = text.replaceRange(sel.start, sel.end, newText);

    _controller.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(
        offset: sel.start + before.length + selected.length,
      ),
    );
  }

  void _insertBold() => _wrapSelection('**', '**');
  void _insertItalic() => _wrapSelection('_', '_');

  void _insertList() {
    final text = _controller.text;
    final sel = _controller.selection;
    if (!sel.isValid) return;

    // Insert a bullet point at the start of the current line or at cursor.
    const bullet = '\n• ';
    final updatedText = text.replaceRange(sel.start, sel.end, bullet);
    _controller.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: sel.start + bullet.length),
    );
  }

  void _insertLink() {
    _wrapSelection('[', '](url)');
  }

  // ─── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Keyboard height for inset padding
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      resizeToAvoidBottomInset: false, // We handle insets manually
      body: SafeArea(
        bottom: false, // We manage bottom inset for the toolbar
        child: Column(
          children: [
            // ─── Header ──────────────────────────────────────
            _buildHeader(),

            const Divider(height: 1, color: Colors.white12),

            // ─── Text area (fills all available space) ───────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  undoController: _undoController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  scrollPhysics: const ClampingScrollPhysics(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.5,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'What did you think?',
                    hintStyle: TextStyle(color: Colors.white38, fontSize: 16),
                  ),
                ),
              ),
            ),

            // ─── Formatting toolbar (above the keyboard) ─────
            _buildToolbar(keyboardHeight),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        children: [
          // Album art thumbnail
          if (widget.albumImageUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: AppCachedImage(
                  imageUrl: widget.albumImageUrl,
                  width: 32,
                  height: 32,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.music_note,
                    color: Colors.white54, size: 18),
              ),
            ),

          // Title
          Expanded(
            child: Text(
              widget.headerTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Done button
          GestureDetector(
            onTap: _onDone,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Text(
                'Done',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(double keyboardHeight) {
    return Container(
      // Push the toolbar above the keyboard
      padding: EdgeInsets.only(
        bottom: keyboardHeight > 0
            ? keyboardHeight
            : MediaQuery.of(context).padding.bottom,
        left: 8,
        right: 8,
        top: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: const Border(
          top: BorderSide(color: Colors.white12),
        ),
      ),
      child: Row(
        children: [
          _ToolbarButton(
            icon: Icons.format_bold,
            onTap: _insertBold,
          ),
          _ToolbarButton(
            icon: Icons.format_italic,
            onTap: _insertItalic,
          ),
          _ToolbarButton(
            icon: Icons.format_list_bulleted,
            onTap: _insertList,
          ),
          _ToolbarButton(
            icon: Icons.link,
            onTap: _insertLink,
          ),

          const Spacer(),

          // Undo / Redo
          ValueListenableBuilder<UndoHistoryValue>(
            valueListenable: _undoController,
            builder: (context, value, child) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ToolbarButton(
                    icon: Icons.undo,
                    onTap: value.canUndo ? () => _undoController.undo() : null,
                    enabled: value.canUndo,
                  ),
                  _ToolbarButton(
                    icon: Icons.redo,
                    onTap: value.canRedo ? () => _undoController.redo() : null,
                    enabled: value.canRedo,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// A single icon button in the formatting toolbar.
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;

  const _ToolbarButton({
    required this.icon,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Icon(
          icon,
          color: enabled ? Colors.white70 : Colors.white24,
          size: 22,
        ),
      ),
    );
  }
}
