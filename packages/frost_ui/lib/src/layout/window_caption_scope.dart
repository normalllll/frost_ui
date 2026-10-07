import 'package:flutter/widgets.dart';
import 'package:frost_ui/src/navigation/shell.dart';

/// The part of a flush sidebar that continues into a Flutter-drawn caption,
/// so the sidebar reads as one column from the top of the window.
@immutable
class FrostCaptionSidebar {
  const FrostCaptionSidebar({required this.width, required this.iconAxis, required this.expansion, required this.style});

  /// The sidebar's right edge from the window's left.
  final double width;

  /// Horizontal centre of the sidebar's icon column, from the window's left;
  /// a mark in the caption centres on it.
  final double iconAxis;

  /// How far the sidebar is expanded, from 0 (collapsed) to 1.
  final double expansion;

  /// Draws the caption's part of the sidebar with [FrostSidebarStyle.frame].
  final FrostSidebarStyle style;

  @override
  bool operator ==(Object other) =>
      other is FrostCaptionSidebar && other.width == width && other.iconAxis == iconAxis && other.expansion == expansion && other.style == style;

  @override
  int get hashCode => Object.hash(width, iconAxis, expansion, style);
}

/// A value the pages hand up to the caption. The window frame owns and
/// disposes it; a page that goes away clears it after the frame, which
/// [clear] allows even if the window frame left too.
class FrostCaptionSlot<T> extends ValueNotifier<T?> {
  FrostCaptionSlot() : super(null);

  bool _disposed = false;

  void clear() {
    if (!_disposed) value = null;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Carries the [FrostCaptionSidebar] from the shell to the caption.
class FrostCaptionSidebarNotifier extends FrostCaptionSlot<FrostCaptionSidebar> {}

/// Carries what the pages draw in the caption between its leading part and
/// the window buttons, such as a tab strip (see [FrostCaptionContent]). The
/// caption keeps the rest of its width draggable.
class FrostCaptionContentNotifier extends FrostCaptionSlot<WidgetBuilder> {}

/// What a Flutter-drawn window caption above the pages tells them, and what
/// it learns from them. Installed by the window frame (frost_window);
/// absent where the platform draws its own title bar.
class FrostWindowCaptionScope extends InheritedWidget {
  const FrostWindowCaptionScope({required this.showsTitle, required super.child, this.sidebar, this.content, super.key});

  /// Whether the caption shows the page title, so page headers can avoid
  /// repeating it.
  final bool showsTitle;

  /// Where a shell whose sidebar continues into the caption reports it (see
  /// [FrostSidebarStyle.continuesIntoCaption]); the caption listens. Null
  /// when this caption does not continue a sidebar.
  final FrostCaptionSidebarNotifier? sidebar;

  /// Where pages put their caption content (see [FrostCaptionContent]); null
  /// when this caption takes none.
  final FrostCaptionContentNotifier? content;

  static bool showsPageTitle(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostWindowCaptionScope>()?.showsTitle ?? false;

  /// The caption's sidebar notifier, without depending on the scope.
  static FrostCaptionSidebarNotifier? sidebarOf(BuildContext context) => context.getInheritedWidgetOfExactType<FrostWindowCaptionScope>()?.sidebar;

  /// The caption's content notifier, without depending on the scope.
  static FrostCaptionContentNotifier? contentOf(BuildContext context) => context.getInheritedWidgetOfExactType<FrostWindowCaptionScope>()?.content;

  @override
  bool updateShouldNotify(FrostWindowCaptionScope oldWidget) =>
      showsTitle != oldWidget.showsTitle || sidebar != oldWidget.sidebar || content != oldWidget.content;
}

/// Puts [content] in the window caption while this widget is mounted, above
/// [child]. Where no caption takes content (the platform draws the title
/// bar) it stands as a bar of [fallbackHeight] above [child] instead.
class FrostCaptionContent extends StatefulWidget {
  const FrostCaptionContent({required this.content, required this.child, this.fallbackHeight = 40, super.key});

  final WidgetBuilder content;
  final Widget child;
  final double fallbackHeight;

  @override
  State<FrostCaptionContent> createState() => _FrostCaptionContentState();
}

class _FrostCaptionContentState extends State<FrostCaptionContent> {
  FrostCaptionContentNotifier? _slot;
  WidgetBuilder? _published;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final slot = FrostWindowCaptionScope.contentOf(context);
    if (slot != _slot) {
      _release();
      _slot = slot;
      _publish();
    }
  }

  @override
  void didUpdateWidget(FrostCaptionContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) _publish();
  }

  // The caption is built before the pages, so it learns of new content after
  // this frame; a fresh builder each time makes it rebuild.
  void _publish() {
    final slot = _slot;
    if (slot == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _slot != slot) return;
      final content = widget.content;
      final published = _published = (context) => content(context);
      slot.value = published;
    });
  }

  void _release() {
    final slot = _slot;
    final published = _published;
    _published = null;
    if (slot == null || published == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (slot.value == published) slot.clear();
    });
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_slot != null) return widget.child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: widget.fallbackHeight,
          child: Builder(builder: widget.content),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
