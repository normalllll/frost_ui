import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frost_ui/src/controls/icon.dart';
import 'package:frost_ui/src/controls/toast.dart';
import 'package:frost_ui/src/foundation/metrics.dart';
import 'package:frost_ui/src/foundation/scope.dart';
import 'package:frost_ui/src/foundation/tokens.dart';
import 'package:frost_ui/src/layout/auto_scaffold.dart';

/// A full page for a failed load, with a retry.
class FrostErrorPage extends StatelessWidget {
  const FrostErrorPage({required String this.message, required this.onRetry, this.fullUrl, this.details, super.key}) : error = null;

  /// The app's localized summary and details for [error].
  const FrostErrorPage.fromError({required Object this.error, required this.onRetry, super.key}) : message = null, fullUrl = null, details = null;

  final String? message;
  final Object? error;
  final VoidCallback onRetry;
  final String? fullUrl;
  final String? details;

  @override
  Widget build(BuildContext context) {
    return FrostAutoScaffold(
      builder: (BuildContext context, FrostSizeLayout layout, Orientation orientation, bool useHorizontalLayout) {
        final content = switch (error) {
          final error? => FrostErrorContent.fromError(error: error, onRetry: onRetry),
          null => FrostErrorContent(message: message!, onRetry: onRetry, fullUrl: fullUrl, details: details),
        };
        return Scaffold(
          appBar: !useHorizontalLayout ? AppBar(title: Text(FrostScope.labelsOf(context).error)) : null,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: content,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// The body of a failed load: icon, summary, retry and collapsed details.
class FrostErrorContent extends StatelessWidget {
  const FrostErrorContent({required String this.message, required this.onRetry, this.retryLabel, this.fullUrl, this.details, super.key}) : error = null;

  /// The app's localized summary and details for [error].
  const FrostErrorContent.fromError({required Object this.error, required this.onRetry, this.retryLabel, super.key})
    : message = null,
      fullUrl = null,
      details = null;

  final String? message;
  final Object? error;
  final VoidCallback onRetry;

  /// Defaults to the retry label.
  final String? retryLabel;
  final String? fullUrl;

  /// Technical detail shown collapsed below the summary.
  final String? details;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final presenter = FrostScope.errorsOf(context);
    final error = this.error;
    final message = error == null ? this.message! : presenter.message(context, error);
    final details = error == null ? this.details : presenter.details(error);
    final hasDetailedMessage = message.contains('\n') || message.length > 120;
    final icons = FrostIconSet.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: FrostIcon(icons.error, size: 44, color: colorScheme.error)),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: hasDetailedMessage ? TextAlign.start : TextAlign.center,
                style: TextStyle(color: colorScheme.onSurface),
              ),
              if (fullUrl case final url?) ...[const SizedBox(height: 12), _ErrorUrl(fullUrl: url)],
              const SizedBox(height: 16),
              Center(
                child: FilledButton.icon(onPressed: onRetry, icon: FrostIcon(icons.refresh), label: Text(retryLabel ?? FrostScope.labelsOf(context).retry)),
              ),
              if (details != null && details.trim().isNotEmpty) ...[const SizedBox(height: 16), FrostErrorDetails(details: details)],
            ],
          ),
        ),
      ),
    );
  }
}

/// Selectable technical detail of an error with a copy action. Full-page
/// errors and inline messages alike keep it collapsed, one tap away.
class FrostErrorDetails extends StatefulWidget {
  const FrostErrorDetails({required this.details, this.initiallyExpanded = false, super.key});

  final String details;
  final bool initiallyExpanded;

  @override
  State<FrostErrorDetails> createState() => _ErrorDetailsState();
}

class _ErrorDetailsState extends State<FrostErrorDetails> {
  late bool _expanded = widget.initiallyExpanded;

  Future<void> _copy(String copiedLabel) async {
    await Clipboard.setData(ClipboardData(text: widget.details));
    FrostToast.copied(copiedLabel);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final labels = FrostScope.labelsOf(context);
    final icons = FrostIconSet.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: FrostIcon(_expanded ? icons.collapse : icons.expand, size: 18),
              label: Text(labels.errorDetails),
            ),
            const Spacer(),
            TextButton.icon(onPressed: () => unawaited(_copy(labels.detailsCopied)), icon: FrostIcon(icons.copy, size: 16), label: Text(labels.copyDetails)),
          ],
        ),
        AnimatedSize(
          duration: FrostMotion.duration(context, FrostMotion.expand),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _expanded
              ? ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: tokens.surfaceInset, borderRadius: BorderRadius.circular(FrostMetrics.controlRadius)),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        widget.details,
                        style: textTheme.bodySmall?.copyWith(fontFamily: 'monospace', color: tokens.textSecondary, height: 1.45),
                      ),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _ErrorUrl extends StatelessWidget {
  const _ErrorUrl({required this.fullUrl});

  final String fullUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayUrl = _withoutQuery(fullUrl);
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);
    return Tooltip(
      message: displayUrl,
      child: Text(displayUrl, maxLines: 3, overflow: TextOverflow.ellipsis, style: textStyle),
    );
  }
}

/// [url] without its query, which can carry tokens or personal parameters.
String _withoutQuery(String url) {
  try {
    return Uri.parse(url).replace(queryParameters: const <String, String>{}).toString();
  } catch (_) {
    final fragmentIndex = url.indexOf('#');
    final queryIndex = url.indexOf('?');
    if (queryIndex < 0 || (fragmentIndex >= 0 && queryIndex > fragmentIndex)) return url;
    return '${url.substring(0, queryIndex)}${fragmentIndex >= 0 ? url.substring(fragmentIndex) : ''}';
  }
}
