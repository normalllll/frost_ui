// Fixtures shared by the frost_data baseline files.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frost_data/frost_data.dart';

import '../../../frost_ui/test/baseline/feedback_baseline_support.dart';

/// What a [BaselineSource] answers.
enum BaselineFeed {
  /// A first page, then an empty next page: the list ends.
  content,

  /// A first page, then a next page that never arrives.
  pending,

  /// The first page never arrives.
  loading,

  /// The first page fails.
  error,

  /// The first page is empty.
  empty,

  /// A first page, then a failing next page.
  footerError,
}

class BaselineSource extends FrostListSource<int> {
  BaselineSource(this.feed, {this.count = 12});
  final BaselineFeed feed;
  final int count;

  @override
  Future<List<int>> initList() => switch (feed) {
    BaselineFeed.loading => Completer<List<int>>().future,
    BaselineFeed.error => Future<List<int>>.error(const BaselineFailure()),
    BaselineFeed.empty => Future.value(const <int>[]),
    _ => Future.value(List.generate(count, (i) => i)),
  };

  @override
  Future<List<int>> nextList() => switch (feed) {
    BaselineFeed.pending => Completer<List<int>>().future,
    BaselineFeed.footerError => Future<List<int>>.error(const BaselineFailure()),
    _ => Future.value(const <int>[]),
  };
}

/// Owns a [BaselineSource] for the subject's lifetime. With [prepare] the
/// source is loaded (first page, and with [exhaust] the next page too) before
/// the subject is built on top of it, instead of by the subject itself.
class BaselineSourceHost extends StatefulWidget {
  const BaselineSourceHost({required this.feed, required this.builder, this.count = 12, this.prepare = false, this.exhaust = false, super.key});
  final BaselineFeed feed;
  final int count;
  final bool prepare, exhaust;
  final Widget Function(BuildContext context, BaselineSource source) builder;
  @override
  State<BaselineSourceHost> createState() => _BaselineSourceHostState();
}

class _BaselineSourceHostState extends State<BaselineSourceHost> {
  late final BaselineSource _source = BaselineSource(widget.feed, count: widget.count);
  @override
  void initState() {
    super.initState();
    if (widget.prepare) _load();
  }

  Future<void> _load() async {
    await _source.refresh(true);
    if (widget.exhaust) await _source.loadMore();
  }

  @override
  void dispose() {
    _source.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _source);
}
