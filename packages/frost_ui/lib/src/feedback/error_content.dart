import 'package:flutter/widgets.dart';

import '../controls/buttons.dart';
import '../display/code_block.dart';
import '../display/disclosure.dart';
import '../foundation/icon_data.dart';
import '../foundation/scope.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import 'empty_state.dart';
import 'error_action_button.dart';

// Keep technical details bounded inside a page or a short inline message.
const _errorDetailsMaximumHeight = 220.0;

/// Error presentation shares the empty state's readable, scrollable structure.
class FrostErrorContent extends StatelessWidget {
  const FrostErrorContent({required String this.message, required this.onRetry, this.retryLabel, this.fullUrl, this.details, super.key}) : error = null;
  const FrostErrorContent.fromError({required Object this.error, required this.onRetry, this.retryLabel, super.key})
    : message = null,
      fullUrl = null,
      details = null;
  final String? message;
  final Object? error;
  final VoidCallback? onRetry;
  final String? retryLabel, fullUrl, details;
  @override
  Widget build(BuildContext context) {
    final presenter = FrostScope.errorsOf(context), labels = FrostScope.labelsOf(context);
    final message = error == null ? this.message! : presenter.message(context, error!);
    final details = error == null ? this.details : presenter.details(error!);
    final hasDetails = details != null && details.trim().isNotEmpty;
    final defaultTitle = FrostErrorTitleScope.maybeOf(context) ?? labels.loadFailed;
    final customIcon = error == null ? null : presenter.icon?.call(context, error!);
    return Semantics(
      liveRegion: true,
      child: FrostEmptyIconInk(
        color: customIcon == null ? FrostThemeTokens.of(context).negativeInk : FrostThemeTokens.of(context).textTertiary,
        child: FrostStateContent(
          icon: customIcon ?? FrostIconSet.of(context).error,
          title: error == null ? defaultTitle : presenter.title?.call(context, error!) ?? defaultTitle,
          message: message,
          actions: Wrap(
            alignment: WrapAlignment.center,
            spacing: FrostGap.related,
            runSpacing: FrostGap.related,
            children: [
              if (error != null && presenter.action?.call(context, error!) != null) FrostErrorActionButton(error: error!, onResolved: onRetry),
              FrostButton(label: retryLabel ?? labels.retry, onPressed: onRetry),
            ],
          ),
          details: fullUrl == null && !hasDetails
              ? null
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (fullUrl case final url?) FrostCodeBlock(text: url, wrap: FrostCodeWrap.anywhere),
                    if (fullUrl != null && hasDetails) const SizedBox(height: FrostGap.group),
                    if (hasDetails) FrostErrorDetails(details: details),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Collapsed technical details retain their expansion state and use the code
/// block's copy feedback and announcement.
class FrostErrorDetails extends StatelessWidget {
  const FrostErrorDetails({required this.details, this.initiallyExpanded = false, super.key}) : quiet = false;

  /// Inline form for a list row or a short message: the toggle is secondary
  /// footnote text instead of a heading. Copy, expansion and details match.
  const FrostErrorDetails.quiet({required this.details, this.initiallyExpanded = false, super.key}) : quiet = true;
  final String details;
  final bool initiallyExpanded, quiet;
  @override
  Widget build(BuildContext context) {
    final title = FrostScope.labelsOf(context).errorDetails;
    final body = ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: _errorDetailsMaximumHeight),
      child: SingleChildScrollView(
        primary: false,
        child: FrostCodeBlock(text: details, wrap: FrostCodeWrap.anywhere),
      ),
    );
    return quiet
        ? FrostQuietDisclosure(title: title, initiallyExpanded: initiallyExpanded, child: body)
        : FrostDisclosure(title: title, initiallyExpanded: initiallyExpanded, child: body);
  }
}

// A loading context supplies a more specific default without changing generic
// error pages or asking Apps to recognize and restyle paged errors themselves.
class FrostErrorTitleScope extends InheritedWidget {
  const FrostErrorTitleScope({required this.title, required super.child, super.key});
  final String title;
  static String? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostErrorTitleScope>()?.title;
  @override
  bool updateShouldNotify(FrostErrorTitleScope oldWidget) => title != oldWidget.title;
}
