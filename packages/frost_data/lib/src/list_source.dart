import 'dart:collection';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:loading_more_list_library/loading_more_list_library.dart';

typedef _ListRequest = ({int generation, Future<bool> future});

enum _ListOperation { refresh, pagination }

/// A failed request which cannot be retried before [retryAt].
/// The app owns transport policy; Frost owns the countdown and retry controls.
abstract interface class FrostRetryAfter {
  DateTime get retryAt;
}

/// The list a source owns. Only [FrostListSource] writes to it; everyone else
/// reads [FrostListSource.items].
class _PageList<T> extends LoadingMoreBase<T> {
  _PageList(this._source);
  final FrostListSource<T> _source;

  @override
  bool get hasMore => _source.hasMore;

  @override
  Future<bool> loadData([bool isLoadMoreAction = false]) => _source._loadData(isLoadMoreAction);

  @override
  Iterable<T> wrapData(Iterable<T> source) => UnmodifiableListView(source);
}

/// A paged list with explicit load phases. Stale responses from a request
/// superseded by a refresh are discarded. It holds its list and exposes it only
/// through the read-only [items]; loading is the only way to change it.
abstract class FrostListSource<T> implements Listenable {
  late final _PageList<T> _list = _PageList<T>(this);
  bool _initialized = false;
  bool _hasMore = true;
  bool _disposed = false;

  Object? _lastError;
  _ListOperation? _failedOperation;
  int _requestId = 0;
  int _refreshRevision = 0;
  _ListRequest? _refreshRequest, _pageRequest;

  final List<VoidCallback> _listeners = <VoidCallback>[];
  bool _notifyScheduled = false;

  UnmodifiableListView<T> get items => UnmodifiableListView(_list);

  /// Emits after every state change, including [notifyDataChanged].
  Stream<Iterable<T>> get rebuild => _list.rebuild;

  bool get initialized => _initialized;

  /// Multi-request subclasses stop filtering/backfill work when their owner
  /// ends, before starting another transport request.
  @protected
  bool get isDisposed => _disposed;

  bool get refreshing => _refreshRequest?.generation == _requestId && (_initialized || _list.isNotEmpty);

  bool get loadingMore => _pageRequest?.generation == _requestId && _refreshRequest == null;

  bool get busy => _list.isLoading || _refreshRequest != null || _pageRequest != null;

  Object? get lastError => _lastError;

  /// Increments only after a successful refresh, including the first load.
  /// Failed and superseded requests never change this revision.
  int get refreshRevision => _refreshRevision;

  DateTime? get retryAt => switch (_lastError) {
    FrostRetryAfter(:final retryAt) => retryAt,
    _ => null,
  };

  bool get canRetry => retryAt == null || !DateTime.now().isBefore(retryAt!);

  /// The full-page state a list view shows: the first load's skeleton (also
  /// before the first request has been issued, so a page never renders an
  /// empty list for a frame), a first-load error, a confirmed empty list,
  /// otherwise the items (with paging and refresh handled in place).
  FrostLoadPhase get phase => switch (_list) {
    _ when _list.isEmpty && lastError != null => FrostLoadPhase.error,
    _ when !initialized && _list.isEmpty => FrostLoadPhase.loading,
    _ when initialized && _list.isEmpty => FrostLoadPhase.empty,
    _ => FrostLoadPhase.content,
  };

  bool get hasMore => !_initialized || _hasMore;

  /// Refreshing an initialized source retains its items (including an empty
  /// result). Use [clearData] explicitly when changing the collection identity.
  @mustCallSuper
  Future<bool> refresh([bool notifyStateChanged = false]) async {
    if (_disposed || !canRetry) return false;
    if (_refreshRequest case final active?) {
      if (active.generation == _requestId) return active.future;
      await active.future;
    }
    final generation = _requestId;
    // LoadingMoreBase returns immediately if a page is already loading. Wait
    // for that operation so the returned Future covers the actual refresh too.
    if (_pageRequest case final active?) await active.future;
    if (_refreshRequest case final active? when active.generation == _requestId) return active.future;
    if (_disposed || generation != _requestId) return false;
    _requestId++;
    _lastError = null;
    _failedOperation = null;
    final previousHasMore = _hasMore;
    final retaining = _initialized || _list.isNotEmpty;
    // An exhausted list must still fetch its first page on an explicit refresh.
    _hasMore = true;
    final result = _list.refresh(notifyStateChanged && !retaining);
    final request = (generation: _requestId, future: result);
    _refreshRequest = request;
    if (retaining) _list.indicatorStatus = _list.isEmpty ? IndicatorStatus.empty : IndicatorStatus.none;
    _notify();
    try {
      final success = await result;
      if (_disposed || request.generation != _requestId) return success;
      if (!success) _hasMore = previousHasMore;
      if (_list.isNotEmpty) _list.indicatorStatus = success ? IndicatorStatus.none : IndicatorStatus.error;
      return success;
    } finally {
      if (identical(_refreshRequest?.future, result)) _refreshRequest = null;
      _notify();
    }
  }

  @mustCallSuper
  Future<bool> loadMore() async {
    if (_disposed || !canRetry) return false;
    if (_refreshRequest case final active?) {
      if (active.generation == _requestId) return active.future;
      await active.future;
    }
    if (_pageRequest case final active?) {
      if (active.generation == _requestId) return active.future;
      await active.future;
    }
    if (_disposed || !canRetry) return false;
    if (_refreshRequest case final active? when active.generation == _requestId) return active.future;
    // errorRefresh delegates retained-content retries here.
    // Retry the failed refresh, rather than silently requesting its next page.
    if (_failedOperation == _ListOperation.refresh) return refresh();
    if (!_initialized) return refresh(true);
    if (!_hasMore || _list.isLoading) return true;
    _lastError = null;
    _failedOperation = null;
    final result = _list.loadMore();
    _pageRequest = (generation: _requestId, future: result);
    _notify();
    try {
      return await result;
    } finally {
      if (identical(_pageRequest?.future, result)) _pageRequest = null;
      _notify();
    }
  }

  /// Retries what failed: the first page of an empty list, otherwise [loadMore].
  @mustCallSuper
  Future<bool> errorRefresh() async {
    if (_list.isEmpty) {
      return await refresh(true);
    }
    return await loadMore();
  }

  Future<bool> _loadData(bool isLoadMoreAction) async {
    final requestId = _requestId;

    try {
      final list = isLoadMoreAction ? await nextList() : await initList();

      if (_disposed || requestId != _requestId) {
        return true;
      }

      if (isLoadMoreAction) {
        _list.addAll(list);
        _hasMore = hasMoreByResult(list);
      } else {
        _list.clear();
        _list.addAll(list);
        _initialized = true;
        _refreshRevision++;
        _hasMore = hasMoreByResult(list);
      }

      return true;
    } catch (e, s) {
      if (_disposed || requestId != _requestId) {
        return true;
      }

      _lastError = e;
      _failedOperation = isLoadMoreAction ? _ListOperation.pagination : _ListOperation.refresh;
      log('$runtimeType: ${isLoadMoreAction ? "pagination" : "refresh"} failed. ${describeError(e)}', stackTrace: s);
      return false;
    }
  }

  void clearData() {
    _requestId++;
    _list.clear();
    _initialized = false;
    _hasMore = true;
    _lastError = null;
    _failedOperation = null;
    _list.isLoading = false;
    _list.indicatorStatus = IndicatorStatus.fullScreenBusying;
    _notify();
  }

  @protected
  void notifyDataChanged() {
    _notify();
  }

  @protected
  bool hasMoreByResult(List<T> list) {
    return list.isNotEmpty;
  }

  /// Sanitised one-line description of a load failure for the debug log.
  /// Override to add transport detail (status, endpoint) without secrets.
  @protected
  String describeError(Object error) => error.runtimeType.toString();

  void _notify() {
    if (_disposed) {
      return;
    }

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      _scheduleNotify();
      return;
    }

    _flushNotify();
  }

  void _scheduleNotify() {
    if (_notifyScheduled) {
      return;
    }

    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      _flushNotify();
    });
  }

  void _flushNotify() {
    if (_disposed) {
      return;
    }

    _list.setState();

    final localListeners = List<VoidCallback>.of(_listeners);
    for (final listener in localListeners) {
      if (_listeners.contains(listener)) {
        listener();
      }
    }
  }

  @override
  void addListener(VoidCallback listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void dispose() {
    _disposed = true;
    _requestId++;
    _listeners.clear();
    _list.dispose();
  }

  Future<List<T>> initList();

  Future<List<T>> nextList();
}

enum FrostLoadPhase { loading, error, empty, content }
