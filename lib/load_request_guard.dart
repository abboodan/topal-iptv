class LoadRequestGuard {
  int _latestRequest = 0;
  bool _loadingMore = false;

  int begin() {
    _latestRequest++;
    return _latestRequest;
  }

  bool isCurrent(int requestId) {
    return requestId == _latestRequest;
  }

  bool tryBeginLoadMore() {
    if (_loadingMore) return false;
    _loadingMore = true;
    return true;
  }

  void endLoadMore() {
    _loadingMore = false;
  }
}
