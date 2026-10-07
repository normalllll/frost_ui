import 'package:flutter/material.dart';
import 'package:frost_ui/src/controls/icon.dart';
import 'package:frost_ui/src/feedback/error_content.dart';
import 'package:frost_ui/src/foundation/metrics.dart';
import 'package:frost_ui/src/foundation/scope.dart';

/// A one-line message inside content: an icon, the text, an optional action,
/// and optional technical detail one tap away.
class FrostCompactMessage extends StatelessWidget {
  const FrostCompactMessage({required FrostIconData this.icon, required String this.message, this.actionLabel, this.onAction, this.details, super.key})
    : error = null;

  /// Inline error from [error]: the app's localized summary, retry, and the
  /// technical detail one tap away.
  const FrostCompactMessage.error({required Object this.error, this.actionLabel, this.onAction, super.key}) : icon = null, message = null, details = null;

  final FrostIconData? icon;
  final String? message;
  final Object? error;

  /// Defaults to the retry label for errors.
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? details;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final error = this.error;
    final presenter = FrostScope.errorsOf(context);
    final message = error == null ? this.message! : presenter.message(context, error);
    final details = error == null ? this.details : presenter.details(error);
    final actionLabel = this.actionLabel ?? (error == null ? null : FrostScope.labelsOf(context).retry);
    final icons = FrostIconSet.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(FrostMetrics.controlRadius)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                FrostIcon(icon ?? icons.error, size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(message, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onAction,
                    icon: FrostIcon(icons.refresh, size: 16),
                    label: Text(actionLabel),
                    style: TextButton.styleFrom(
                      overlayColor: Colors.transparent,
                      minimumSize: const Size(0, FrostMetrics.controlHeight),
                      tapTargetSize: MaterialTapTargetSize.padded,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ],
            ),
            if (details != null && details.trim().isNotEmpty) FrostErrorDetails(details: details),
          ],
        ),
      ),
    );
  }
}
