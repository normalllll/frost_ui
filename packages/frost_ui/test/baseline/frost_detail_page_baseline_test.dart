import 'package:flutter/material.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'nav_overlay_support.dart';

void _removed(Page<Object?> _) {}

// FrostDetailPage is a Page, not a widget: it is shown by a Navigator whose
// root page is a plain one.
Widget _navigator(Page<Object?> detail) => windowed(
  Navigator(
    pages: [
      const MaterialPage<void>(
        key: ValueKey('root'),
        child: ColoredBox(
          color: Color(0xFF203040),
          child: Center(child: Text('Root page')),
        ),
      ),
      detail,
    ],
    onDidRemovePage: _removed,
  ),
);

const _child = ColoredBox(
  color: Color(0xFF402030),
  child: Center(child: Text('Detail page')),
);

BaselineCase _case(String id, Page<Object?> Function() page, {List<BaselineEnv> envs = const [BaselineEnv.standard]}) =>
    BaselineCase(id, (_) => _navigator(page()), height: 400, envs: envs);

void main() {
  baselineGroup('FrostDetailPage', [
    _case(
      'FrostDetailPage/required',
      () => const FrostDetailPage<Object?>(key: ValueKey('detail'), child: _child),
      envs: BaselineEnv.all,
    ),
    _case('FrostDetailPage/opaque=false', () => const FrostDetailPage<Object?>(key: ValueKey('detail'), opaque: false, child: _child)),
    _case('FrostDetailPage/name', () => const FrostDetailPage<Object?>(key: ValueKey('detail'), name: '/detail', child: _child)),
    _case(
      'FrostDetailPage.media/required',
      () => const FrostDetailPage<Object?>.media(key: ValueKey('detail'), child: _child),
      envs: BaselineEnv.all,
    ),
    _case('FrostDetailPage.media/opaque=false', () => const FrostDetailPage<Object?>.media(key: ValueKey('detail'), opaque: false, child: _child)),
    _case('FrostDetailPage.media/name', () => const FrostDetailPage<Object?>.media(key: ValueKey('detail'), name: '/detail', child: _child)),
  ]);
}
