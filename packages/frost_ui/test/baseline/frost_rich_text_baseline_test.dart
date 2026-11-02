import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noopLink(Uri _) {}
void _noopTarget(String _) {}

const _plain = 'A plain sentence with nothing special in it.';
const _marked = 'Hello **bold** and *italic* with `code`, see https://example.com/page, thanks @alice for the #flutter tip.';

void main() {
  baselineGroup('FrostRichText', [
    BaselineCase('FrostRichText/required', (_) => const FrostRichText(text: _plain), envs: BaselineEnv.all),
    BaselineCase('FrostRichText/text=marked', (_) => const FrostRichText(text: _marked), envs: BaselineEnv.all),
    BaselineCase(
      'FrostRichText/onLink',
      (_) => const FrostRichText(text: _marked, onLink: _noopLink),
      envs: BaselineEnv.themes,
    ),
    BaselineCase('FrostRichText/onMention', (_) => const FrostRichText(text: _marked, onMention: _noopTarget)),
    BaselineCase('FrostRichText/onHashtag', (_) => const FrostRichText(text: _marked, onHashtag: _noopTarget)),
    BaselineCase(
      'FrostRichText/onLink+onMention+onHashtag',
      (_) => const FrostRichText(text: _marked, onLink: _noopLink, onMention: _noopTarget, onHashtag: _noopTarget),
      envs: [BaselineEnv.standard, BaselineEnv.touch],
    ),
    for (final role in [FrostTextRole.footnote, FrostTextRole.headline])
      BaselineCase('FrostRichText/role=${role.name}', (_) => FrostRichText(text: _marked, role: role)),
    BaselineCase('FrostRichText/selectable=false', (_) => const FrostRichText(text: _marked, selectable: false)),
  ]);
}
