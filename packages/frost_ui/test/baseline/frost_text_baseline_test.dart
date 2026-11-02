import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

const _long = 'A sentence long enough to wrap onto several lines when the room is narrow, and then some more words to be sure of it.';
const _span = TextSpan(
  text: 'Rich ',
  children: [
    TextSpan(
      text: 'bold',
      style: TextStyle(fontWeight: FontWeight.w700),
    ),
    TextSpan(text: ' text'),
  ],
);

/// Fixed width, so alignment has room to act on.
Widget _boxed(Widget text) => SizedBox(width: 300, child: text);

void main() {
  baselineGroup('FrostText', [
    // Default constructor.
    const BaselineCase('FrostText/required', _required, envs: BaselineEnv.all),
    for (final role in FrostTextRole.values)
      BaselineCase('FrostText/role=${role.name}', (_) => FrostText('Text', role: role), envs: [BaselineEnv.standard, BaselineEnv.largeText]),
    for (final tone in FrostTextTone.values) BaselineCase('FrostText/tone=${tone.name}', (_) => FrostText('Text', tone: tone), envs: BaselineEnv.themes),
    const BaselineCase('FrostText/numeric', _numeric),
    const BaselineCase('FrostText/tabular', _tabular),
    const BaselineCase('FrostText/content', _content, envs: BaselineEnv.themes),
    const BaselineCase('FrostText/maxLines', _maxLines, envs: [BaselineEnv.standard, BaselineEnv.narrow]),
    const BaselineCase('FrostText/maxLines+overflow=ellipsis', _ellipsis, envs: [BaselineEnv.standard, BaselineEnv.narrow]),
    const BaselineCase('FrostText/overflow=fade', _fade, envs: [BaselineEnv.narrow]),
    for (final align in [TextAlign.start, TextAlign.center, TextAlign.end])
      BaselineCase('FrostText/textAlign=${align.name}', (_) => _boxed(FrostText('Aligned', textAlign: align))),
    const BaselineCase('FrostText/selectable', _selectable),
    const BaselineCase('FrostText/semanticsLabel', _semanticsLabel),
    const BaselineCase('FrostText/required+long', _longText, envs: [BaselineEnv.standard, BaselineEnv.narrow, BaselineEnv.largeText]),

    // FrostText.rich
    const BaselineCase('FrostText.rich/required', _richRequired, envs: BaselineEnv.all),
    for (final role in [FrostTextRole.headline, FrostTextRole.footnote])
      BaselineCase('FrostText.rich/role=${role.name}', (_) => FrostText.rich(_span, role: role)),
    for (final tone in [FrostTextTone.secondary, FrostTextTone.negative])
      BaselineCase('FrostText.rich/tone=${tone.name}', (_) => FrostText.rich(_span, tone: tone), envs: BaselineEnv.themes),
    const BaselineCase('FrostText.rich/numeric', _richNumeric),
    const BaselineCase('FrostText.rich/tabular', _richTabular),
    const BaselineCase('FrostText.rich/content', _richContent),
    const BaselineCase('FrostText.rich/maxLines+overflow=ellipsis', _richEllipsis, envs: [BaselineEnv.narrow]),
    const BaselineCase('FrostText.rich/textAlign=center', _richCenter),
    const BaselineCase('FrostText.rich/selectable', _richSelectable),
    const BaselineCase('FrostText.rich/semanticsLabel', _richSemantics),
  ]);
}

Widget _required(BuildContext context) => const FrostText('Text');
Widget _numeric(BuildContext context) => const FrostText('0123456789', numeric: true);
Widget _tabular(BuildContext context) => const FrostText('0123456789', tabular: true);
Widget _content(BuildContext context) => const FrostText('日本語の名前 中文名字', content: true);
Widget _maxLines(BuildContext context) => const FrostText(_long, maxLines: 2);
Widget _ellipsis(BuildContext context) => const FrostText(_long, maxLines: 2, overflow: TextOverflow.ellipsis);
Widget _fade(BuildContext context) => const FrostText(_long, maxLines: 1, overflow: TextOverflow.fade);
Widget _selectable(BuildContext context) => const FrostText('Selectable', selectable: true);
Widget _semanticsLabel(BuildContext context) => const FrostText('3 / 5', semanticsLabel: 'Three of five');
Widget _longText(BuildContext context) => const FrostText(_long);
Widget _richRequired(BuildContext context) => const FrostText.rich(_span);
Widget _richNumeric(BuildContext context) => const FrostText.rich(TextSpan(text: '0123456789'), numeric: true);
Widget _richTabular(BuildContext context) => const FrostText.rich(TextSpan(text: '0123456789'), tabular: true);
Widget _richContent(BuildContext context) => const FrostText.rich(TextSpan(text: '日本語の名前 中文名字'), content: true);
Widget _richEllipsis(BuildContext context) => const FrostText.rich(TextSpan(text: _long), maxLines: 2, overflow: TextOverflow.ellipsis);
Widget _richCenter(BuildContext context) => _boxed(const FrostText.rich(_span, textAlign: TextAlign.center));
Widget _richSelectable(BuildContext context) => const FrostText.rich(_span, selectable: true);
Widget _richSemantics(BuildContext context) => const FrostText.rich(_span, semanticsLabel: 'Rich text label');
