import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Library-only link between a page template and a search field in its page
/// header. On narrow windows the field lists its suggestions over the page
/// body instead of in an anchored panel; while it does, the template keeps
/// the body laid out but hides it, and section tabs below the header hide too.
class FrostHeaderSearchBody extends ChangeNotifier {
  /// The template's whole area; the suggestions take its part below the header
  /// row. Written by the template's render object.
  RenderBox? page;

  bool _showing = false, _notifyScheduled = false, _disposed = false;
  final _painters = <RenderObject>{};

  /// The field's suggestions cover the page body.
  bool get showing => _showing;

  /// Set by the field while it builds. Render objects that hide content read
  /// [showing] at paint and hit-test time, so the body and the suggestions
  /// swap in the same frame; widgets that exclude focus follow after it.
  set showing(bool value) {
    if (_showing == value) return;
    _showing = value;
    for (final painter in _painters) {
      painter
        ..markNeedsPaint()
        ..markNeedsSemanticsUpdate();
    }
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase != SchedulerPhase.persistentCallbacks && phase != SchedulerPhase.midFrameMicrotasks) {
      notifyListeners();
      return;
    }
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  void addPainter(RenderObject painter) => _painters.add(painter);
  void removePainter(RenderObject painter) => _painters.remove(painter);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class FrostHeaderSearchBodyScope extends InheritedWidget {
  const FrostHeaderSearchBodyScope({required this.link, required super.child, super.key});
  final FrostHeaderSearchBody link;
  static FrostHeaderSearchBody? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostHeaderSearchBodyScope>()?.link;
  @override
  bool updateShouldNotify(FrostHeaderSearchBodyScope oldWidget) => link != oldWidget.link;
}

/// Library-only: hides its child while [link] shows suggestions, keeping it
/// laid out so its scroll position and State stay as they were.
class FrostHeaderSearchConcealed extends SingleChildRenderObjectWidget {
  const FrostHeaderSearchConcealed({required this.link, super.child, super.key});
  final FrostHeaderSearchBody link;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHeaderSearchConcealed(link);
  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) => (renderObject as _RenderHeaderSearchConcealed).link = link;
}

class _RenderHeaderSearchConcealed extends RenderProxyBox {
  _RenderHeaderSearchConcealed(this._link);
  FrostHeaderSearchBody _link;
  set link(FrostHeaderSearchBody value) {
    if (identical(_link, value)) return;
    if (attached) _link.removePainter(this);
    _link = value;
    if (attached) _link.addPainter(this);
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _link.addPainter(this);
  }

  @override
  void detach() {
    _link.removePainter(this);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_link.showing) super.paint(context, offset);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) => !_link.showing && super.hitTest(result, position: position);

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (!_link.showing) super.visitChildrenForSemantics(visitor);
  }
}

/// Library-only: reports the template's area to [link].
class FrostHeaderSearchPage extends SingleChildRenderObjectWidget {
  const FrostHeaderSearchPage({required this.link, super.child, super.key});
  final FrostHeaderSearchBody link;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHeaderSearchPage(link);
  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) => (renderObject as _RenderHeaderSearchPage).link = link;
}

class _RenderHeaderSearchPage extends RenderProxyBox {
  _RenderHeaderSearchPage(this._link);
  FrostHeaderSearchBody _link;
  set link(FrostHeaderSearchBody value) {
    if (identical(_link, value)) return;
    if (identical(_link.page, this)) _link.page = null;
    _link = value;
    if (attached) _link.page = this;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _link.page = this;
  }

  @override
  void detach() {
    if (identical(_link.page, this)) _link.page = null;
    super.detach();
  }
}
