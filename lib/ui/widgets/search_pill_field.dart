import 'package:flutter/material.dart';
import 'package:flutter_test_project/ui/theme/tokens.dart';
import 'package:flutter_test_project/ui/widgets/glass.dart';
import 'package:flutter_test_project/ui/widgets/round_icon_button.dart';

/// A search input as a Liquid Glass pill ([LiquidSurface]): 40 px tall like
/// [RoundIconButton], fully rounded, search icon on the left. Shows a small spinner while [busy], else
/// an ✕ that calls [onClear] once there's text. Sits next to a
/// [RoundIconButton] in page headers (Search, Add), matching Profile's
/// "Search your reviews" bar.
class SearchPillField extends StatelessWidget {
  const SearchPillField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onClear,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.busy = false,
  });

  final TextEditingController controller;
  final String hintText;
  final VoidCallback onClear;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return LiquidSurface(
      borderRadius: AppRadius.pillAll,
      child: Material(
        type: MaterialType.transparency,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: RoundIconButton.size,
          child: Row(
            children: [
              const SizedBox(width: AppSpacing.md),
              const Icon(Icons.search, color: Colors.white70, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  cursorColor: AppColors.primary,
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: const TextStyle(
                      color: Colors.white60,
                      fontSize: 15,
                    ),
                    hintMaxLines: 1,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (busy)
                const SizedBox.square(
                  dimension: RoundIconButton.size,
                  child: Center(
                    child: SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white70,
                        ),
                      ),
                    ),
                  ),
                )
              else
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) => value.text.isEmpty
                      ? const SizedBox(width: AppSpacing.md)
                      : Semantics(
                          button: true,
                          label: 'Clear search',
                          child: InkWell(
                            onTap: onClear,
                            customBorder: const CircleBorder(),
                            child: const SizedBox.square(
                              dimension: RoundIconButton.size,
                              child: Icon(
                                Icons.close,
                                color: Colors.white70,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
