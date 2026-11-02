import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void main() {
  baselineGroup('FrostActivityIndicator', [
    BaselineCase('FrostActivityIndicator/required', (_) => const FrostActivityIndicator(semanticLabel: 'Loading'), envs: BaselineEnv.all),
    for (final size in [FrostControlSize.small, FrostControlSize.compact, FrostControlSize.large])
      BaselineCase(
        'FrostActivityIndicator/size=${size.name}',
        (_) => FrostActivityIndicator(size: size, semanticLabel: 'Loading'),
        envs: BaselineEnv.themes,
      ),
    BaselineCase('FrostActivityIndicator/semanticLabel=null', (_) => const FrostActivityIndicator(semanticLabel: null)),
  ]);
}
