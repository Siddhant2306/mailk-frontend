import '../models/converter_record.dart';

class ConverterCatalogCache {
  ConverterCatalogCache({
    this.ttl = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static final shared = ConverterCatalogCache();

  final Duration ttl;
  final DateTime Function() _clock;
  final Map<String, Map<int, _CachedCatalogPage>> _pages = {};
  final Map<String, int> _revisions = {};
  var _generation = 0;

  ConverterCatalogPage? read({
    required String search,
    required int? brandId,
    required int pageSize,
    required int page,
  }) {
    final key = _key(search, brandId, pageSize);
    final cachedPages = _pages[key];
    final cachedPage = cachedPages?[page];
    if (cachedPage == null) {
      return null;
    }
    if (!_clock().isBefore(cachedPage.expiresAt)) {
      cachedPages!.remove(page);
      if (cachedPages.isEmpty) {
        _pages.remove(key);
      }
      return null;
    }
    return cachedPage.page;
  }

  ({int generation, int revision}) revision({
    required String search,
    required int? brandId,
    required int pageSize,
  }) {
    return (
      generation: _generation,
      revision: _revisions[_key(search, brandId, pageSize)] ?? 0,
    );
  }

  void write({
    required String search,
    required int? brandId,
    required int pageSize,
    required ({int generation, int revision}) revision,
    required ConverterCatalogPage page,
  }) {
    final key = _key(search, brandId, pageSize);
    if (revision.generation != _generation ||
        (_revisions[key] ?? 0) != revision.revision) {
      return;
    }
    final cachedPages = _pages.putIfAbsent(key, () => {});
    cachedPages[page.page] = _CachedCatalogPage(
      page: page,
      expiresAt: _clock().add(ttl),
    );
  }

  void invalidate({
    required String search,
    required int? brandId,
    required int pageSize,
  }) {
    final key = _key(search, brandId, pageSize);
    _pages.remove(key);
    _revisions.update(key, (revision) => revision + 1, ifAbsent: () => 1);
  }

  void invalidateAll() {
    _pages.clear();
    _revisions.clear();
    _generation++;
  }

  String _key(String search, int? brandId, int pageSize) {
    return '${search.trim()}\u0000${brandId ?? ''}\u0000$pageSize';
  }
}

class _CachedCatalogPage {
  const _CachedCatalogPage({required this.page, required this.expiresAt});

  final ConverterCatalogPage page;
  final DateTime expiresAt;
}
