import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malik/core/constants/constants.dart';
import 'package:malik/models/car_brand.dart';
import 'package:malik/models/converter_draft.dart';
import 'package:malik/models/converter_record.dart';
import 'package:malik/screens/brands_screen.dart';
import 'package:malik/screens/catalog_screen.dart';
import 'package:malik/screens/search_screen.dart';
import 'package:malik/services/brand_service.dart';
import 'package:malik/services/converter_catalog_cache.dart';
import 'package:malik/services/converter_service.dart';
import 'package:malik/services/authenticated_api_client.dart';

void main() {
  test('parses converter rows and page totals from the catalogue response', () {
    final result = ConverterCatalogPage.fromJson(
      {
        'items': [
          {
            'id': 42,
            'code_reference': 'ABC-42',
            'brand_id': 8,
            'model': 'Swift',
            'images': ['https://example.com/converter.png'],
            'markings': ['86J C04'],
            'monolith_weight_g': 750,
            'pt_ppm': 400,
          },
        ],
        'total': 450,
        'page': 1,
        'page_size': 20,
        'total_pages': 23,
      },
      requestedPage: 1,
      requestedPageSize: 20,
      brandsById: const {8: 'Suzuki'},
    );

    expect(result.total, 450);
    expect(result.hasMore, isTrue);
    expect(result.converters.single.id, 42);
    expect(result.converters.single.brandName, 'Suzuki');
    expect(result.converters.single.model, 'Swift');
    expect(result.converters.single.images, [
      'https://example.com/converter.png',
    ]);
  });

  test('catalog pages are reused until refresh or cache expiry', () {
    var now = DateTime(2026);
    final cache = ConverterCatalogCache(
      ttl: const Duration(minutes: 5),
      clock: () => now,
    );
    const page = ConverterCatalogPage(
      converters: [ConverterRecord(id: 1, codeReference: 'CAT-1')],
      total: 1,
      page: 1,
      pageSize: 20,
    );

    cache.write(
      search: '',
      brandId: null,
      pageSize: 20,
      revision: 0,
      page: page,
    );
    expect(
      cache.read(search: '', brandId: null, pageSize: 20, page: 1),
      same(page),
    );
    expect(
      cache.read(search: 'marking', brandId: null, pageSize: 20, page: 1),
      isNull,
    );

    cache.invalidate(search: '', brandId: null, pageSize: 20);
    expect(
      cache.read(search: '', brandId: null, pageSize: 20, page: 1),
      isNull,
    );

    cache.write(
      search: '',
      brandId: null,
      pageSize: 20,
      revision: 1,
      page: page,
    );
    now = now.add(const Duration(minutes: 6));
    expect(
      cache.read(search: '', brandId: null, pageSize: 20, page: 1),
      isNull,
    );
  });

  test('converter brands use the authenticated API client', () async {
    final apiClient = _FakeAuthenticatedApiClient(
      responseData: {
        'data': [
          {
            'id': 2,
            'external_id': 'suzuki',
            'name': 'Suzuki',
            'logo_url': 'https://example.com/suzuki.png',
            'converter_count': 3,
          },
        ],
      },
    );
    final service = BrandService(apiClient: apiClient);

    final brands = await service.getConverterBrands(forceRefresh: true);

    expect(apiClient.requestedPaths, [ApiConstants.brands]);
    expect(brands.single.id, 2);
    expect(brands.single.name, 'Suzuki');
  });

  testWidgets('catalog requests more pages and keeps the backend total', (
    tester,
  ) async {
    final service = _FakeConverterService();

    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CatalogScreen(
            converterService: service,
            brandService: _FakeBrandService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('40 converters'), findsOneWidget);
    expect(find.text('CAT-1'), findsOneWidget);
    expect(service.requestedPages, [1]);

    for (var attempt = 0; attempt < 4; attempt++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
      await tester.pump();
    }
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
    await tester.pumpAndSettle();

    expect(service.requestedPages, [1, 2]);
  });

  testWidgets('user-role catalog view loads without showing admin actions', (
    tester,
  ) async {
    final service = _FakeConverterService();

    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CatalogScreen(
            converterService: service,
            brandService: _FakeBrandService(),
            isAdmin: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.queries.single.page, 1);
    expect(find.text('40 converters'), findsOneWidget);
    expect(find.text('CAT-1'), findsOneWidget);
    expect(find.byKey(const ValueKey('catalog-add-converter')), findsNothing);
  });

  testWidgets(
    'catalog cards show labeled fields and highlight search matches',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CatalogScreen(
              converterService: _FakeConverterService(),
              brandService: _FakeBrandService(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in [
        'Code:',
        'Make:',
        'Model:',
        'Marking:',
        'Country:',
        'Weight:',
      ]) {
        expect(find.text(label), findsWidgets);
      }

      await tester.enterText(find.byType(TextField), '86J C04');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      final matchingText = find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText() == '86J C04' &&
            (widget.text as TextSpan).children?.any(
                  (span) => span.style?.backgroundColor != null,
                ) ==
                true,
      );
      expect(matchingText, findsWidgets);
    },
  );

  testWidgets('catalog starts filtered when opened from a brand card', (
    tester,
  ) async {
    final service = _FakeConverterService();

    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CatalogScreen(
            converterService: service,
            brandService: _FakeBrandService(),
            initialBrandId: 2,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.queries.single.brandId, 2);
    expect(find.text('Filter: Suzuki'), findsOneWidget);
  });

  testWidgets('admin add action opens the existing converter form', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CatalogScreen(
            converterService: _FakeConverterService(),
            brandService: _FakeBrandService(),
            isAdmin: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('catalog-add-converter')));
    await tester.pumpAndSettle();

    expect(find.text('Add Converter'), findsOneWidget);
  });

  testWidgets('tapping a brand reports the selection for catalog filtering', (
    tester,
  ) async {
    CarBrand? selectedBrand;

    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrandsScreen(
            brandService: _FakeBrandService(),
            onBrandSelected: (brand) => selectedBrand = brand,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Suzuki'));
    expect(selectedBrand?.id, 2);
  });

  testWidgets('brand selection is combined with debounced server search', (
    tester,
  ) async {
    final service = _FakeConverterService();

    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CatalogScreen(
            converterService: service,
            brandService: _FakeBrandService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Suzuki'));
    await tester.pumpAndSettle();
    expect(service.queries.last.brandId, 2);

    await tester.enterText(find.byType(TextField), '86J C04');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(service.queries.last.search, '86J C04');
    expect(service.queries.last.brandId, 2);
    expect(service.queries.last.page, 1);
    expect(find.text('2 converters'), findsOneWidget);
  });

  testWidgets('tapping a converter fetches detail by its ID', (tester) async {
    final service = _FakeConverterService();

    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CatalogScreen(
            converterService: service,
            brandService: _FakeBrandService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('CAT-1'));
    await tester.pumpAndSettle();

    expect(service.requestedDetails, [1]);
    expect(find.text('Reference'), findsOneWidget);
    expect(find.text('CAT-1'), findsOneWidget);
    expect(find.text('PGM CONTENT'), findsOneWidget);
  });

  testWidgets('search tab displays paginated catalog matches', (tester) async {
    final service = _FakeConverterService();

    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchScreen(
            converterService: service,
            brandService: _FakeBrandService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Search'), findsOneWidget);
    expect(find.text('CAT-1'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '86J C04');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(service.queries.last.search, '86J C04');
    expect(service.queries.last.page, 1);
    expect(find.text('2 converters'), findsOneWidget);
  });
}

class _FakeConverterService implements ConverterService {
  final requestedPages = <int>[];
  final queries = <({int page, String? search, int? brandId})>[];
  final requestedDetails = <int>[];

  @override
  Future<String> uploadConverterImage({
    required List<int> bytes,
    required String fileName,
  }) async => '';

  @override
  Future<int> createConverter(ConverterDraft draft) async => 0;

  @override
  String messageFor(Object error) => 'Request failed.';

  @override
  Future<ConverterCatalogPage> getConverters({
    required int page,
    int pageSize = 20,
    String? search,
    int? brandId,
    Map<int, String> brandsById = const {},
    bool forceRefresh = false,
  }) async {
    requestedPages.add(page);
    queries.add((page: page, search: search, brandId: brandId));
    final total = search == null || search.isEmpty ? 40 : 2;
    final start = (page - 1) * pageSize;
    final count = (total - start).clamp(0, pageSize);
    final converters = List.generate(count, (index) {
      final id = start + index + 1;
      return ConverterRecord(
        id: id,
        codeReference: 'CAT-$id',
        brandId: 2,
        brandName: 'Suzuki',
        model: 'Swift',
        markings: const ['86J C04'],
        monolithWeightGrams: 750,
        images: const [],
        ptPpm: 400,
      );
    });
    return ConverterCatalogPage(
      converters: converters,
      total: total,
      page: page,
      pageSize: pageSize,
      totalPages: (total / pageSize).ceil(),
    );
  }

  @override
  Future<ConverterRecord> getConverter(
    int converterId, {
    Map<int, String> brandsById = const {},
  }) async {
    requestedDetails.add(converterId);
    return ConverterRecord(
      id: converterId,
      codeReference: 'CAT-$converterId',
      brandId: 2,
      brandName: 'Suzuki',
      model: 'Swift',
      country: 'India',
      markings: const ['86J C04'],
      monolithWeightGrams: 750,
      ptPpm: 400,
      pdPpm: 50,
      rhPpm: 415,
      remarks: 'Test remarks',
    );
  }
}

class _FakeBrandService implements BrandService {
  @override
  Future<List<CarBrand>> getBrands({bool forceRefresh = false}) async =>
      const [];

  @override
  Future<List<CarBrand>> getConverterBrands({bool forceRefresh = false}) async {
    return const [
      CarBrand(id: 2, slug: 'suzuki', name: 'Suzuki', logoUrl: null),
    ];
  }
}

class _FakeAuthenticatedApiClient implements AuthenticatedApiClient {
  _FakeAuthenticatedApiClient({required this.responseData});

  final dynamic responseData;
  final requestedPaths = <String>[];

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    requestedPaths.add(path);
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: responseData,
    );
  }

  @override
  Future<Response<dynamic>> post(String path, {Object? data}) {
    throw UnimplementedError();
  }

  @override
  Future<Options> createAuthorizedOptions() {
    throw UnimplementedError();
  }
}
