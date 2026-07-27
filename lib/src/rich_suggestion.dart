import 'package:flutter/material.dart';

import 'api/location_picker_api.dart';

class RichSuggestion extends StatelessWidget {
  final VoidCallback onTap;
  final PlaceSuggestion suggestion;

  const RichSuggestion(this.suggestion, this.onTap, {super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      child: InkWell(
        onTap: onTap,
        child: Container(
            margin: EdgeInsets.all(5),
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: RichText(
                    text: TextSpan(children: getStyledTexts(context)),
                  ),
                )
              ],
            )),
      ),
    );
  }

  /// Divide o texto da sugestão em três trechos (antes / casado / depois).
  /// Os offsets vêm do `matched_substrings` da API, então são recortados
  /// contra o tamanho real do texto — valores inconsistentes estouravam
  /// `RangeError` dentro do `substring`.
  List<TextSpan> getStyledTexts(BuildContext context) {
    const TextStyle normalStyle = TextStyle(
      color: Colors.grey,
      fontSize: 15,
      fontWeight: FontWeight.w300,
    );
    const TextStyle boldStyle = TextStyle(
      color: Colors.grey,
      fontSize: 15,
      fontWeight: FontWeight.w500,
    );

    final String text = suggestion.description;
    final int start = suggestion.matchOffset.clamp(0, text.length);
    final int end =
        (start + suggestion.matchLength).clamp(start, text.length);

    final List<TextSpan> result = [];

    if (start > 0) {
      result.add(TextSpan(text: text.substring(0, start), style: normalStyle));
    }
    if (end > start) {
      result.add(TextSpan(text: text.substring(start, end), style: boldStyle));
    }
    if (end < text.length) {
      result.add(TextSpan(
        text: text.substring(end),
        style: const TextStyle(color: Colors.grey, fontSize: 15),
      ));
    }

    return result;
  }
}
