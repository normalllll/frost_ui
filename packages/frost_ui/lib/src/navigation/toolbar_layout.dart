part of 'toolbar.dart';

enum _Kind { leading, fullMeasure, compactMeasure, item, middle, moreMeasure, more }

enum _Form { full, compact, hidden }

enum _Middle { full, collapsed, hidden }

class _ToolbarIdentity {
  const _ToolbarIdentity(this.stage, this.forms, this.middle);
  final int stage;
  final List<_Form> forms;
  final _Middle middle;

  /// The whole end cluster appeared or went, at full width, and nothing else
  /// changed: no control that stays on screen moved.
  bool onlyClusterCameOrWent(_ToolbarIdentity other) =>
      stage == other.stage && middle == other.middle && forms.isEmpty != other.forms.isEmpty && [...forms, ...other.forms].every((form) => form == _Form.full);

  @override
  bool operator ==(Object other) => other is _ToolbarIdentity && stage == other.stage && middle == other.middle && listEquals(forms, other.forms);
  @override
  int get hashCode => Object.hash(stage, Object.hashAll(forms), middle);
}

class _Data extends ContainerBoxParentData<RenderBox> {
  _Kind kind = _Kind.leading;
  int index = 0;
  bool title = false, visible = false, icon = false;
  double titleMinimum = 0;
  int shrinkPriority = 1;
}

class _ToolbarSlot extends ParentDataWidget<_Data> {
  const _ToolbarSlot({
    required this.kind,
    this.index = 0,
    this.title = false,
    this.titleMinimum = 0,
    this.shrinkPriority = 1,
    this.icon = false,
    required super.child,
  });
  final _Kind kind;
  final int index;
  final bool title, icon;
  final double titleMinimum;
  final int shrinkPriority;
  @override
  void applyParentData(RenderObject renderObject) {
    final data = renderObject.parentData! as _Data;
    if (data.kind == kind &&
        data.index == index &&
        data.title == title &&
        data.titleMinimum == titleMinimum &&
        data.shrinkPriority == shrinkPriority &&
        data.icon == icon) {
      return;
    }
    data.kind = kind;
    data.index = index;
    data.title = title;
    data.titleMinimum = titleMinimum;
    data.shrinkPriority = shrinkPriority;
    data.icon = icon;
    renderObject.parent?.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => _ToolbarLayout;
}

class _ToolbarConstraints extends BoxConstraints {
  const _ToolbarConstraints(
    double width,
    double height, {
    this.form = _Form.full,
    this.middle = _Middle.full,
    this.overflow = const [],
    this.trailingEdge = false,
  }) : super(minWidth: width, maxWidth: width, maxHeight: height);
  final _Form form;
  final _Middle middle;
  final List<int> overflow;
  final bool trailingEdge;
  @override
  bool operator ==(Object other) =>
      other is _ToolbarConstraints &&
      super == other &&
      form == other.form &&
      middle == other.middle &&
      trailingEdge == other.trailingEdge &&
      listEquals(overflow, other.overflow);
  @override
  int get hashCode => Object.hash(super.hashCode, form, middle, Object.hashAll(overflow), trailingEdge);
}

class _ToolbarLayout extends MultiChildRenderObjectWidget {
  const _ToolbarLayout({
    required this.identity,
    required this.width,
    required this.minimumMiddle,
    required this.maximumMiddle,
    required this.collapsedWidth,
    required this.hasMiddle,
    required this.menusYieldBeforeActions,
    required this.middleRoom,
    required this.rowSpan,
    required this.gap,
    required this.edgeInset,
    required this.startRoom,
    required this.endRoom,
    required this.minimumHeight,
    required this.direction,
    required this.items,
    required this.controlsCount,
    required this.iconInset,
    required super.children,
  });
  final FrostLayoutIdentity identity;
  final double width, minimumMiddle, maximumMiddle, collapsedWidth, gap, minimumHeight;
  final bool hasMiddle;

  /// Leading menus shrink to their minimum before actions move to More.
  final bool menusYieldBeforeActions;
  final FrostToolbarMiddleRoom? middleRoom;
  final FrostHeaderRowSpan? rowSpan;
  final double? edgeInset;
  final double startRoom, endRoom;
  final TextDirection direction;
  final List<FrostToolbarItem> items;
  final int controlsCount;
  final double iconInset;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderToolbar(this);
  @override
  void updateRenderObject(BuildContext context, _RenderToolbar renderObject) {
    renderObject.config = this;
    renderObject.markNeedsLayout();
  }
}

class _RenderToolbar extends RenderBox with ContainerRenderObjectMixin<RenderBox, _Data>, RenderBoxContainerDefaultsMixin<RenderBox, _Data> {
  _RenderToolbar(this.config);
  _ToolbarLayout config;
  int stage = 0;
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _Data) child.parentData = _Data();
  }

  // Everything on one row at full width: what the row needs before it folds.
  // Items answer through their measuring copies; the live ones may not exist yet.
  Iterable<RenderBox> get _measured => getChildrenAsList().where(
    (child) => switch ((child.parentData! as _Data).kind) {
      _Kind.leading || _Kind.fullMeasure => true,
      _ => false,
    },
  );

  @override
  double computeMaxIntrinsicWidth(double height) {
    final parts = _measured.map((child) => child.getMaxIntrinsicWidth(double.infinity)).toList();
    return parts.fold(0.0, (sum, width) => sum + width) +
        config.gap * math.max(0, parts.length - 1) +
        (config.hasMiddle ? config.minimumMiddle + config.gap : 0);
  }

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _measured.fold(config.minimumHeight, (tallest, child) => math.max(tallest, child.getMaxIntrinsicHeight(double.infinity))) + FrostGap.inline * 2;
  @override
  double computeMinIntrinsicHeight(double width) => computeMaxIntrinsicHeight(width);
  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(Size(config.width, computeMaxIntrinsicHeight(double.infinity)));

  @override
  void performLayout() {
    final leading = <RenderBox>[], live = <int, RenderBox>{};
    final full = <int, double>{}, compact = <int, double>{};
    RenderBox? middle;
    late RenderBox more;
    var moreWidth = 0.0, height = config.minimumHeight;
    for (final child in getChildrenAsList()) {
      final data = child.parentData! as _Data;
      data.visible = false;
      switch (data.kind) {
        case _Kind.item:
          live[data.index] = child;
        case _Kind.middle:
          middle = child;
        case _Kind.more:
          more = child;
        case _Kind.leading || _Kind.fullMeasure || _Kind.compactMeasure || _Kind.moreMeasure:
          child.layout(BoxConstraints(maxHeight: constraints.maxHeight), parentUsesSize: true);
          height = math.max(height, child.size.height);
          switch (data.kind) {
            case _Kind.leading:
              leading.add(child);
            case _Kind.fullMeasure:
              full[data.index] = child.size.width;
            case _Kind.compactMeasure:
              compact[data.index] = child.size.width;
            case _Kind.moreMeasure:
              moreWidth = child.size.width;
            default:
              break;
          }
      }
    }
    final forms = List.filled(config.items.length, _Form.full);
    final leadWidths = [for (final child in leading) child.size.width];
    var mode = config.hasMiddle ? _Middle.full : _Middle.hidden;
    var middleWidth = config.hasMiddle ? config.minimumMiddle : 0.0;
    double itemWidth(int index) => switch (forms[index]) {
      _Form.full => full[index]!,
      _Form.compact => compact[index]!,
      _Form.hidden => 0,
    };
    bool itemIcon(int index) => config.items[index]._iconOnly(forms[index] == _Form.compact);
    // Visible slots in placement order, each with whether it is a bare icon
    // target: leading, controls, middle, trailing actions, then More.
    List<(double, bool)> slots() => [
      for (var i = 0; i < leading.length; i++)
        if (leadWidths[i] > 0) (leadWidths[i], (leading[i].parentData! as _Data).icon),
      for (var i = 0; i < math.min(config.controlsCount, forms.length); i++)
        if (forms[i] != _Form.hidden) (itemWidth(i), itemIcon(i)),
      if (middleWidth > 0) (middleWidth, mode == _Middle.collapsed),
      for (var i = config.controlsCount; i < forms.length; i++)
        if (forms[i] != _Form.hidden) (itemWidth(i), itemIcon(i)),
      if (forms.contains(_Form.hidden)) (moreWidth, true),
    ];
    double total() {
      final values = slots();
      var sum = 0.0;
      for (var i = 0; i < values.length; i++) {
        sum += values[i].$1 + (i == 0 ? 0 : _gapBetween(values[i - 1].$2, values[i].$2));
      }
      return sum;
    }

    final available = config.width.isFinite ? config.width : total() + (config.hasMiddle ? config.maximumMiddle - config.minimumMiddle : 0);
    // Room the trailing cluster may take past the row end so its last glyph
    // lands on the keyline: the same shift the placement below applies. Rows
    // fit against it, so that room is not left as extra gap before the cluster.
    double shiftRoom() {
      final edgeInset = config.edgeInset;
      final trailing = [
        for (var i = config.controlsCount; i < forms.length; i++)
          if (forms[i] != _Form.hidden) i,
      ];
      final icon = forms.contains(_Form.hidden) || trailing.isNotEmpty && itemIcon(trailing.last);
      return edgeInset == null || !icon ? 0 : math.max(0, math.min(config.endRoom, config.iconInset - edgeInset));
    }

    double room() => available + shiftRoom();
    final order = List.generate(forms.length, (i) => i)
      ..sort((a, b) {
        final result = config.items[b].priority.index.compareTo(config.items[a].priority.index);
        if (result != 0) return result;
        // Merge an existing More/group into the shared overflow before hiding
        // peers. Replacing its trigger costs no width and prevents two Mores.
        final group = (config.items[b]._isOverflowGroup ? 1 : 0) - (config.items[a]._isOverflowGroup ? 1 : 0);
        return group == 0 ? a.compareTo(b) : group;
      });
    stage = 0;
    for (final picker in [false, true]) {
      for (final i in order) {
        if (total() <= room()) break;
        final item = config.items[i];
        if (item._canCompact && item._isPicker == picker) {
          forms[i] = _Form.compact;
          stage = picker ? 2 : 1;
        }
      }
    }
    // Without a middle slot the title moves nothing else in the row, so its
    // arrival, departure and ellipsis are not a change of the row's layout.
    bool titleMovesNothing(int i) {
      final data = leading[i].parentData! as _Data;
      return data.title && data.shrinkPriority != 0 && !config.hasMiddle;
    }

    void shrinkTitles({bool menusOnly = false}) {
      final indices = [for (var i = 0; i < leading.length; i++) i]
        ..sort((a, b) {
          final priority = (leading[a].parentData! as _Data).shrinkPriority.compareTo((leading[b].parentData! as _Data).shrinkPriority);
          // The entry closest to the row's start keeps its width longest.
          return priority == 0 ? b.compareTo(a) : priority;
        });
      for (final i in indices) {
        if (total() <= room()) break;
        final data = leading[i].parentData! as _Data;
        if (menusOnly && data.shrinkPriority != 0) continue;
        if (data.title) {
          leadWidths[i] = math.max(math.min(data.titleMinimum, leadWidths[i]), leadWidths[i] - (total() - room()));
          if (!titleMovesNothing(i)) stage = math.max(stage, 4);
        }
      }
    }

    if (config.menusYieldBeforeActions) shrinkTitles(menusOnly: true);
    for (final i in order) {
      if (total() <= room()) break;
      if (config.items[i].priority != FrostToolbarPriority.high) {
        forms[i] = _Form.hidden;
        stage = math.max(stage, 3);
      }
    }
    shrinkTitles();
    if (total() > room() && config.hasMiddle) {
      if (config.collapsedWidth > 0) {
        mode = _Middle.collapsed;
        middleWidth = config.collapsedWidth;
      } else {
        // A flexible editor without a declared alternative must keep its State
        // and focus. Give it the remaining space, with room for a text target and two affordances
        // as the minimum usable field; truly smaller rows use the existing scroll path.
        final minimum = math.min(config.minimumMiddle, config.minimumHeight * 3 + config.gap * 2);
        middleWidth = math.max(minimum, middleWidth - (total() - room()));
      }
      stage = 5;
    }
    if (total() > room()) stage = 6;
    if (mode == _Middle.full) middleWidth += math.min(config.maximumMiddle - middleWidth, math.max(0, room() - total()));
    // Uncapped room after the other content took its final forms.
    config.middleRoom?.width = config.hasMiddle ? math.max(0, room() - total() + middleWidth) : 0;
    final layoutIdentity = _ToolbarIdentity(stage, List.unmodifiable(forms), mode);
    final previous = config.identity.current;
    config.identity.update(
      layoutIdentity,
      viewport: available,
      quiet: !config.hasMiddle && previous is _ToolbarIdentity && layoutIdentity.onlyClusterCameOrWent(previous),
    );
    final contentWidth = math.max(available, total() - shiftRoom());
    // How much of the end room the content before the cluster already took.
    final absorbed = math.min(shiftRoom(), math.max(0.0, total() - available));
    final overflow = [
      for (var i = 0; i < forms.length; i++)
        if (forms[i] == _Form.hidden) i,
    ];
    final visible = <RenderBox>[];
    for (var i = 0; i < leading.length; i++) {
      leading[i].layout(_ToolbarConstraints(leadWidths[i], constraints.maxHeight), parentUsesSize: true);
      if (leadWidths[i] > 0) visible.add(leading[i]);
    }
    final leadingCount = visible.length;
    var shownControls = 0;
    if (middle != null) {
      middle.layout(_ToolbarConstraints(middleWidth, constraints.maxHeight, middle: mode), parentUsesSize: true);
      if (mode != _Middle.hidden) visible.add(middle);
    }
    for (var i = 0; i < forms.length; i++) {
      live[i]!.layout(
        _ToolbarConstraints(
          forms[i] == _Form.hidden ? full[i]! : itemWidth(i),
          constraints.maxHeight,
          form: forms[i],
          trailingEdge: overflow.isEmpty && i == forms.lastIndexWhere((form) => form != _Form.hidden),
        ),
        parentUsesSize: true,
      );
      if (forms[i] != _Form.hidden) {
        if (i < config.controlsCount) {
          visible.insert(leadingCount + shownControls++, live[i]!);
        } else {
          visible.add(live[i]!);
        }
      }
    }
    more.layout(_ToolbarConstraints(overflow.isEmpty ? 0 : moreWidth, constraints.maxHeight, overflow: overflow), parentUsesSize: true);
    if (overflow.isNotEmpty) visible.add(more);
    for (final child in visible) {
      height = math.max(height, child.size.height);
    }
    size = constraints.constrain(Size(contentWidth, height + FrostGap.inline * 2));
    var cursor = 0.0;
    var atTrailing = false;
    final edgeInset = config.edgeInset;
    bool iconTarget(RenderBox box) {
      final data = box.parentData! as _Data;
      return switch (data.kind) {
        _Kind.leading => data.icon,
        _Kind.more => true,
        _Kind.item => itemIcon(data.index),
        _Kind.middle => mode == _Middle.collapsed,
        _ => false,
      };
    }

    // Leading icon slots carry their own edge offset; only actions shift.
    double? graphicInset(RenderBox box) => (box.parentData! as _Data).kind != _Kind.leading && iconTarget(box) ? config.iconInset : null;

    final firstInset = visible.isEmpty ? null : graphicInset(visible.first);
    final lastInset = visible.isEmpty ? null : graphicInset(visible.last);
    final startShift = edgeInset == null || firstInset == null ? 0.0 : math.max(-config.startRoom, edgeInset - firstInset);
    final endShift = edgeInset == null || lastInset == null ? 0.0 : math.min(config.endRoom, lastInset - edgeInset);
    for (final (index, child) in visible.indexed) {
      final data = child.parentData! as _Data;
      data.visible = true;
      if (index > 0) cursor += _gapBetween(iconTarget(visible[index - 1]), iconTarget(child));
      if (!atTrailing && (data.kind == _Kind.item && data.index >= config.controlsCount || data.kind == _Kind.more)) {
        atTrailing = true;
        final trailing = visible.where((child) {
          final data = child.parentData! as _Data;
          return data.kind == _Kind.item && data.index >= config.controlsCount || data.kind == _Kind.more;
        }).toList();
        var extent = 0.0;
        for (final (i, box) in trailing.indexed) {
          extent += box.size.width + (i == 0 ? 0 : _gapBetween(iconTarget(trailing[i - 1]), iconTarget(box)));
        }
        // Content before the cluster may already reach into the end room; the
        // cluster still starts one gap after it and the shift adds the room.
        cursor = math.max(cursor - absorbed, size.width - extent);
      }
      // Align the complete trailing cluster, never just its last glyph. Pure
      // icons retain the shared square plate and their mutual target spacing.
      final shift = atTrailing
          ? endShift
          : identical(child, visible.first)
          ? startShift
          : 0.0;
      final position = cursor + shift;
      data.offset = Offset(config.direction == TextDirection.ltr ? position : size.width - position - child.size.width, (size.height - child.size.height) / 2);
      cursor += child.size.width;
    }
    if (config.rowSpan case final span?) _reportSpan(span, visible, stage == 0);
  }

  /// The free stretch between the leading-side content and the trailing
  /// cluster, for a template that may place section tabs in it.
  void _reportSpan(FrostHeaderRowSpan span, List<RenderBox> visible, bool full) {
    final ltr = config.direction == TextDirection.ltr;
    double? leadEdge, trailEdge;
    for (final child in visible) {
      final data = child.parentData! as _Data;
      final trailing = data.kind == _Kind.item && data.index >= config.controlsCount || data.kind == _Kind.more;
      final left = data.offset.dx, right = left + child.size.width;
      if (trailing) {
        trailEdge = ltr ? math.min(trailEdge ?? right, left) : math.max(trailEdge ?? left, right);
      } else {
        leadEdge = ltr ? math.max(leadEdge ?? left, right) : math.min(leadEdge ?? right, left);
      }
    }
    span.report(
      box: this,
      full: full,
      start: (ltr ? leadEdge : trailEdge) ?? 0,
      end: (ltr ? trailEdge : leadEdge) ?? size.width,
      height: size.height,
      contentBefore: leadEdge != null,
      contentAfter: trailEdge != null,
    );
  }

  // Adjacent bare icon targets are spaced by their own hit areas, as in
  // platform navigation bars; the plates stay centred inside those areas.
  // Text, the title, the middle slot and custom items keep the toolbar gap.
  double _gapBetween(bool a, bool b) => a && b ? 0 : config.gap;

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in getChildrenAsList()) {
      final data = child.parentData! as _Data;
      if (data.visible) context.paintChild(child, offset + data.offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in getChildrenAsList().reversed) {
      final data = child.parentData! as _Data;
      if (data.visible &&
          result.addWithPaintOffset(
            offset: data.offset,
            position: position,
            hitTest: (result, position) => child.hitTest(result, position: position),
          )) {
        return true;
      }
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    for (final child in getChildrenAsList()) {
      if ((child.parentData! as _Data).visible) visitor(child);
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('collapseStage', stage));
  }
}
