import 'package:frost_ui/src/feedback/refresh_indicator.dart' show FrostSliverFillBody;
import 'package:material_ui/material_ui.dart';

import 'baseline.dart';

void main() {
  const height = 300.0;
  const child = Center(child: Text('Nothing here'));
  baselineGroup('FrostSliverFillBody', [
    BaselineCase(
      'FrostSliverFillBody/required',
      (_) => const Scaffold(body: FrostSliverFillBody(child: child)),
      height: height,
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostSliverFillBody/physics',
      (_) => const Scaffold(
        body: FrostSliverFillBody(physics: BouncingScrollPhysics(), child: child),
      ),
      height: height,
    ),
    BaselineCase(
      'FrostSliverFillBody/sliverHeader',
      (_) => const Scaffold(
        body: FrostSliverFillBody(
          sliverHeader: SliverToBoxAdapter(child: SizedBox(height: 60, child: Text('Header'))),
          child: child,
        ),
      ),
      height: height,
    ),
    BaselineCase(
      'FrostSliverFillBody/leadingSlivers',
      (_) => const Scaffold(
        body: FrostSliverFillBody(
          leadingSlivers: [SliverToBoxAdapter(child: SizedBox(height: 60, child: Text('Leading')))],
          child: child,
        ),
      ),
      height: height,
    ),
    BaselineCase(
      'FrostSliverFillBody/leadingSlivers+sliverHeader',
      (_) => const Scaffold(
        body: FrostSliverFillBody(
          leadingSlivers: [SliverToBoxAdapter(child: SizedBox(height: 60, child: Text('Leading')))],
          sliverHeader: SliverToBoxAdapter(child: SizedBox(height: 60, child: Text('Header'))),
          child: child,
        ),
      ),
      height: height,
    ),
  ]);
}
