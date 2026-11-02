import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

const _content = SizedBox(width: 240, height: 80, child: Center(child: FrostText('Surface')));

void main() {
  baselineGroup('FrostSurface', [
    const BaselineCase('FrostSurface/required', _required, envs: BaselineEnv.all),
    for (final role in FrostSurfaceRole.values)
      BaselineCase(
        'FrostSurface/role=${role.name}',
        (_) => FrostSurface(role: role, child: _content),
        envs: BaselineEnv.themes,
      ),
    BaselineCase(
      'FrostSurface/borderRadius',
      (_) => const FrostSurface(role: FrostSurfaceRole.panel, borderRadius: BorderRadius.all(Radius.circular(24)), child: _content),
      envs: BaselineEnv.themes,
    ),
    BaselineCase('FrostSurface/borderRadius=zero', (_) => const FrostSurface(role: FrostSurfaceRole.panel, borderRadius: BorderRadius.zero, child: _content)),
    BaselineCase(
      'FrostSurface/borderRadius=directional',
      (_) => const FrostSurface(
        role: FrostSurfaceRole.panel,
        borderRadius: BorderRadiusDirectional.only(topStart: Radius.circular(24)),
        child: _content,
      ),
    ),
    BaselineCase(
      'FrostSurface/role=onMediaChrome+borderRadius=zero',
      (_) => const FrostSurface(role: FrostSurfaceRole.onMediaChrome, borderRadius: BorderRadius.zero, child: _content),
    ),
    for (final role in [FrostSurfaceRole.panel, FrostSurfaceRole.chrome, FrostSurfaceRole.module])
      BaselineCase(
        'FrostSurface/role=${role.name}+edge=none',
        (_) => FrostSurface(role: role, edge: FrostSurfaceEdge.none, child: _content),
        envs: BaselineEnv.themes,
      ),
    for (final role in [FrostSurfaceRole.panel, FrostSurfaceRole.chrome, FrostSurfaceRole.overlay])
      BaselineCase(
        'FrostSurface/role=${role.name}+elevated=false',
        (_) => FrostSurface(role: role, elevated: false, child: _content),
        envs: BaselineEnv.themes,
      ),
    for (final join in [FrostSurfaceJoin.above, FrostSurfaceJoin.below])
      BaselineCase(
        'FrostSurface/join=${join.name}',
        (_) => FrostSurface(role: FrostSurfaceRole.chrome, join: join, child: _content),
        envs: BaselineEnv.themes,
      ),
    BaselineCase(
      'FrostSurface/join=above+below',
      (_) => const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FrostSurface(role: FrostSurfaceRole.chrome, join: FrostSurfaceJoin.below, child: _content),
          FrostSurface(role: FrostSurfaceRole.chrome, join: FrostSurfaceJoin.above, child: _content),
        ],
      ),
    ),
  ]);
}

Widget _required(BuildContext context) => const FrostSurface(role: FrostSurfaceRole.panel, child: _content);
