import 'package:flutter/widgets.dart';

/// Keeps a [TabBarView] page built after it has been shown, so swiping away
/// and back preserves its scroll position and loaded content.
class FrostKeepAlive extends StatefulWidget {
  const FrostKeepAlive({required this.child, super.key});

  final Widget child;

  @override
  State<FrostKeepAlive> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<FrostKeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
