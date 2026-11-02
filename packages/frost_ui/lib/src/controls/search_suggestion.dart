import 'package:flutter/foundation.dart';

import '../foundation/icon_data.dart';

/// A suggestion's data and application callbacks; the panel retains input focus.
class FrostSearchSuggestion {
  const FrostSearchSuggestion({
    required this.label,
    this.icon,
    this.dataColor,
    this.detail,
    this.inlineDetail = false,
    this.value,
    required this.onSelected,
    this.onRemove,
    this.keepsOpen = false,
  });
  final String label;
  final FrostIconData? icon;

  /// Category index into the current theme, using the same dot as FrostTag.
  /// When supplied, this marker takes the leading place of [icon].
  final int? dataColor;
  final String? detail;

  /// Uses FrostListRow.inlineSubtitle: the full label takes precedence over an
  /// ellipsized, single-line detail. Complete detail remains in semantics.
  final bool inlineDetail;

  /// Trailing metadata, with the shared row's wrapping and accessibility rules.
  final String? value;
  final VoidCallback onSelected;
  final VoidCallback? onRemove;

  /// Selecting this suggestion leaves the list open, with focus in the field,
  /// refreshed for the new query and with nothing highlighted, so several
  /// suggestions can be chosen in a row (adding tags, say) and Enter then submits
  /// the query. Arrow keys start a highlight. Esc, a tap outside and submitting
  /// still close the list. By default a selection closes it.
  final bool keepsOpen;
}

class FrostSearchSuggestionGroup {
  const FrostSearchSuggestionGroup({this.title, required this.items, this.actionLabel, this.onAction, this.keepsOpen = false});
  final String? title;
  final List<FrostSearchSuggestion> items;

  /// Every suggestion of the group keeps the list open when selected, as if it
  /// set [FrostSearchSuggestion.keepsOpen] itself.
  final bool keepsOpen;

  /// A text action at the end of the group's title row, such as clearing
  /// history or managing saved tags. It is reached with the arrow keys before
  /// the group's items and, like them, leaves editing focus in the field.
  /// The suggestions stay open after it runs. Both fields are required for
  /// the action to show; a group without items shows neither title nor action.
  final String? actionLabel;
  final VoidCallback? onAction;
}
