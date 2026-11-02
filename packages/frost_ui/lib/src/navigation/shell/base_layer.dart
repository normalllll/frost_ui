part of 'shell.dart';

class _ShellBase extends StatelessWidget {
  const _ShellBase({required this.enabled, required this.child});
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) => enabled
      ? FrostSurface(role: FrostSurfaceRole.base, child: child)
      : FrostSurfaceScope(isGlass: false, background: FrostThemeTokens.of(context).canvas, child: child);
}
