import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:google_map_location_picker/generated/l10n.dart';

/// Custom Search input field, showing the search and clear icons.
class SearchInput extends StatefulWidget {
  const SearchInput(
    this.onSearchInput, {
    super.key,
    this.boxDecoration,
    this.hintText,
  });

  final ValueChanged<String> onSearchInput;
  final BoxDecoration? boxDecoration;
  final String? hintText;

  @override
  State<StatefulWidget> createState() => SearchInputState();
}

class SearchInputState extends State<SearchInput> {
  TextEditingController editController = TextEditingController();
  FocusNode focus = FocusNode();

  Timer? debouncer;

  StreamSubscription<bool>? _keyboardVisibilitySubscription;

  bool hasSearchEntry = false;

  @override
  void initState() {
    super.initState();
    editController.addListener(onSearchInputChange);
    _keyboardVisibilitySubscription =
        KeyboardVisibilityController().onChange.listen((bool visible) {
      if (!visible) focus.unfocus();
    });
  }

  @override
  void dispose() {
    // Sem cancelar, o timer dispara `onSearchInput` depois do unmount e a
    // subscription mantém o State vivo (e chama `focus` já descartado).
    debouncer?.cancel();
    _keyboardVisibilitySubscription?.cancel();

    editController.removeListener(onSearchInputChange);
    editController.dispose();
    focus.dispose();

    super.dispose();
  }

  void onSearchInputChange() {
    if (editController.text.isEmpty) {
      debouncer?.cancel();
      widget.onSearchInput(editController.text);
      return;
    }

    if (debouncer?.isActive ?? false) {
      debouncer!.cancel();
    }

    debouncer = Timer(Duration(milliseconds: 500), () {
      widget.onSearchInput(editController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: widget.boxDecoration ??
          BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black54
                : Colors.white,
          ),
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: <Widget>[
          Icon(Icons.search),
          SizedBox(width: 8),
          Expanded(
            child: TextField(
              focusNode: focus,
              controller: editController,
              decoration: InputDecoration(
                hintText: widget.hintText ??
                    S.of(context)?.search_place ??
                    'Search place',
                border: InputBorder.none,
              ),
              textCapitalization: TextCapitalization.sentences,
              onChanged: (value) {
                setState(() {
                  hasSearchEntry = value.isNotEmpty;
                });
              },
            ),
          ),
          SizedBox(width: 8),
          hasSearchEntry
              ? GestureDetector(
                  child: Icon(Icons.clear),
                  onTap: () {
                    editController.clear();
                    setState(() {
                      hasSearchEntry = false;
                    });
                  },
                )
              : SizedBox(),
        ],
      ),
    );
  }
}
