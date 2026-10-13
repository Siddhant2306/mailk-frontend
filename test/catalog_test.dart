import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malik/core/constants/constants.dart';
import 'package:malik/models/car_brand.dart';
import 'package:malik/models/converter_draft.dart';
import 'package:malik/models/converter_record.dart';
import 'package:malik/screens/brands_screen.dart';
import 'package:malik/screens/catalog_screen.dart';
import 'package:malik/screens/converter_detail_screen.dart';
import 'package:malik/screens/search_screen.dart';
import 'package:malik/services/brand_service.dart';
import 'package:malik/services/converter_catalog_cache.dart';
import 'package:malik/services/converter_service.dart';
import 'package:malik/services/authenticated_api_client.dart';
import 'package:malik/widgets/profile/converter_form_sheet.dart';

void main() {
  test('parses converter rows and page totals from the catalogue response', () {
    final result = ConverterCatalogPage.fromJson(
      {
        'items': [
          {
            'id': 42,
            'code_reference': 'ABC-42',
            'converter_code': 420042,
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
    expect(result.converters.single.converterCode, '420042');
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
      revision: cache.revision(search: '', brandId: null, pageSize: 20),
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
      revision: cache.revision(search: '', brandId: null, pageSize: 20),
      page: page,
    );
    now = now.add(const Duration(minutes: 6));
    expect(
      cache.read(search: '', brandId: null, pageSize: 20, page: 1),
      isNull,
    );
  });

  test('converter mutations use the admin converter endpoints', () async {
    final apiClient = _FakeAuthenticatedApiClient(responseData: {});
    final service = ConverterService(
      apiClient: apiClient,
      catalogCache: ConverterCatalogCache(),
    );
    const draft = ConverterDraft(
      brandId: 8,
      codeReference: 'ABC-42',
      model: 'Swift',
    );

    await service.updateConverter(42, draft);
    await service.deleteConverter(42);

    expect(apiClient.requestedPaths, [
      '/api/v1/admin/converters/42',
      '/api/v1/admin/converters/42',
    ]);
    expect(apiClient.requestedMethods, ['PATCH', 'DELETE']);
    expect(apiClient.requestedData.single, draft.toJson(includeNulls: true));
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

  test('unknown brand uses its backend ID and appears only once', () async {
    final apiClient = _FakeAuthenticatedApiClient(
      responseData: {
        'data': [
          {'brand_id': 87, 'name': 'Unknown'},
          {'id': 99, 'name': 'unknown'},
          {'id': 2, 'name': 'Suzuki'},
        ],
      },
    );
    final service = BrandService(apiClient: apiClient);

    final brands = await service.getConverterBrands(forceRefresh: true);
    final unknownBrands = brands.where(
      (brand) => brand.name.toLowerCase() == 'unknown',
    );

    expect(unknownBrands, hasLength(1));
    expect(unknownBrands.single.id, 87);
  });

  test('converter API receives selected brand ID as brand_id', () async {
    final apiClient = _FakeAuthenticatedApiClient(
      responseData: {'items': [], 'total': 0},
    );
    final service = ConverterService(
      apiClient: apiClient,
      catalogCache: ConverterCatalogCache(),
    );

    await service.getConverters(page: 1, brandId: 87, forceRefresh: true);

    expect(apiClient.requestedQueryParameters.single['brand_id'], 87);
  });

  test('create and update reject more than four converter images', () async {
    final apiClient = _FakeAuthenticatedApiClient(responseData: {});
    final service = ConverterService(
      apiClient: apiClient,
      catalogCache: ConverterCatalogCache(),
    );
    final draft = ConverterDraft(
      brandId: 8,
      codeReference: 'ABC-42',
      images: List.generate(5, (index) => 'https://example.com/$index.png'),
    );

    await expectLater(
      service.createConverter(draft),
      throwsA(isA<ConverterImageLimitException>()),
    );
    await expectLater(
      service.updateConverter(42, draft),
      throwsA(isA<ConverterImageLimitException>()),
    );

    expect(apiClient.requestedPaths, isEmpty);
  });

  testWidgets('admin can type to find and create a converter with Unknown', (
    tester,
  ) async {
    final converterService = _FakeConverterService();

    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConverterFormSheet(
            converterService: converterService,
            brandService: _FakeBrandService(
              converterBrands: const [
                CarBrand(id: 2, slug: 'suzuki', name: 'Suzuki', logoUrl: null),
                CarBrand(
                  id: 87,
                  slug: 'unknown',
                  name: 'Unknown',
                  logoUrl: null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'REF-UNKNOWN');
    final brandField = find.byKey(const ValueKey('converter-brand-selector'));
    await tester.ensureVisible(brandField);
    await tester.tap(brandField);
    await tester.enterText(brandField, 'Unk');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unknown').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVE CONVERTER'));
    await tester.pumpAndSettle();

    expect(converterService.createdDraft?.brandId, 87);
    expect(converterService.createdDraft?.codeReference, 'REF-UNKNOWN');
  });

  testWidgets('converter form smoothly animates when keyboard opens', (
    tester,
  ) async {
    const screenSize = Size(400, 600);
    final converterService = _FakeConverterService();
    final brandService = _FakeBrandService();

    await tester.binding.setSurfaceSize(screenSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Widget buildForm({required EdgeInsets viewInsets}) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: screenSize, viewInsets: viewInsets),
          child: Material(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConverterFormSheet(
                converterService: converterService,
                brandService: brandService,
              ),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildForm(viewInsets: EdgeInsets.zero));
    await tester.pumpAndSettle();

    final sheet = find.byKey(const ValueKey('converter-form-sheet'));
    final initialHeight = tester.getSize(sheet).height;
    await tester.pumpWidget(
      buildForm(viewInsets: const EdgeInsets.only(bottom: 300)),
    );
    await tester.pump(const Duration(milliseconds: 125));

    final intermediateHeight = tester.getSize(sheet).height;
    expect(intermediateHeight, greaterThan(initialHeight));
    expect(intermediateHeight, lessThan(582));

    await tester.pumpAndSettle();
    expect(tester.getSize(sheet).height, closeTo(582, 0.1));
  });

  testWidgets('converter form adds images one at a time from source cards', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConverterFormSheet(
            converterService: _FakeConverterService(),
            brandService: _FakeBrandService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0/4 selected'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Photo'), findsOneWidget);
    expect(find.text('Add Image (+)'), findsNothing);
  });

  testWidgets('converter image section offers Gallery and Photo choices', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConverterFormSheet(
            converterService: _FakeConverterService(),
            brandService: _FakeBrandService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Photo'), findsOneWidget);
    expect(find.text('Pick from storage'), findsOneWidget);
    expect(find.text('Take a photo'), findsOneWidget);
  });

  testWidgets('brand screen displays Unknown and its backend count', (
    tester,
  ) async {
    CarBrand? selectedBrand;

    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrandsScreen(
            brandService: _FakeBrandService(
              converterBrands: const [
                CarBrand(
                  id: 87,
                  slug: 'unknown',
                  name: 'Unknown',
                  logoUrl: 'https://example.com/unknown.png',
                  converterCount: 7,
                ),
              ],
            ),
            onBrandSelected: (brand) => selectedBrand = brand,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unknown'), findsOneWidget);
    expect(find.text('7 converters'), findsOneWidget);
    await tester.tap(find.text('Unknown'));

    expect(selectedBrand?.id, 87);
  });

  testWidgets('brand screen omits brands without a logo', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrandsScreen(
            brandService: _FakeBrandService(
              converterBrands: const [
                CarBrand(
                  id: 88,
                  slug: 'logo-less',
                  name: 'Logo-less',
                  logoUrl: null,
                  converterCount: 9,
                ),
                CarBrand(
                  id: 87,
                  slug: 'unknown',
                  name: 'Unknown',
                  logoUrl: 'https://example.com/unknown.png',
                  converterCount: 7,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Logo-less'), findsNothing);
    expect(find.text('Unknown'), findsOneWidget);
    expect(find.text('1 brands • 7 converters'), findsOneWidget);
  });

  testWidgets('converter detail markings are left aligned', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: ConverterDetailScreen(
          converterId: 1,
          converterService: _FakeConverterService(),
          brandsById: const {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final marking = tester.widget<Text>(find.text('86J C04'));
    expect(marking.textAlign, TextAlign.left);
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

  testWidgets('catalog converter thumbnail uses enlarged size', (
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

    expect(
      tester.getSize(find.byKey(const ValueKey('catalog-converter-image')).first).width,
      128,
    );
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

  testWidgets('converter edit and delete controls are admin-only', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConverterDetailScreen(
          converterId: 1,
          converterService: _FakeConverterService(),
          brandsById: const {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Edit converter'), findsNothing);
    expect(find.byTooltip('Delete converter'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: ConverterDetailScreen(
          converterId: 1,
          converterService: _FakeConverterService(),
          brandsById: const {},
          isAdmin: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Edit converter'), findsOneWidget);
    expect(find.byTooltip('Delete converter'), findsOneWidget);
  });

  testWidgets('converter detail image fills the hero with title overlaid', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ConverterDetailScreen(
          converterId: 1,
          converterService: _FakeConverterService(),
          brandsById: const {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final heroImage = find.byWidgetPredicate(
      (widget) => widget is Image && widget.fit == BoxFit.contain,
    );
    expect(heroImage, findsOneWidget);
    expect(tester.getSize(heroImage).width, 400);
    expect(
      tester.getSize(find.byKey(const ValueKey('converter-detail-image-hero'))).height,
      360,
    );
    expect(find.text('ID  AUTO-1'), findsOneWidget);
    expect(find.text('Swift'), findsNWidgets(2));
  });

  testWidgets(
    'catalog cards show labeled fields and highlight search matches',
    (tester) async {
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

      for (final label in [
        'Reference:',
        'Make:',
        'Model:',
        'Marking:',
        'Country:',
        'Weight:',
      ]) {
        expect(find.text(label), findsWidgets);
      }

      await tester.enterText(find.byType(TextField), 'CAT 1');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(service.queries.last.search, 'CAT 1');

      final matchingCodes = tester.widgetList<RichText>(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText && widget.text.toPlainText() == 'CAT-1',
        ),
      );
      int yellowHighlightCount(InlineSpan span) {
        if (span is! TextSpan) return 0;
        return (span.style?.backgroundColor == const Color(0xFFFFE082)
                ? 1
                : 0) +
            (span.children?.fold<int>(
                  0,
                  (count, child) => count + yellowHighlightCount(child),
                ) ??
                0);
      }

      expect(
        matchingCodes.any((text) => yellowHighlightCount(text.text) == 2),
        isTrue,
      );
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

    await tester.tap(find.text('CAT-1').first);
    await tester.pumpAndSettle();

    expect(service.requestedDetails, [1]);
    expect(find.text('Reference'), findsOneWidget);
    expect(find.text('CAT-1'), findsOneWidget);
    expect(find.text('PGM CONTENT'), findsOneWidget);
    expect(find.text('Markings'), findsOneWidget);
    expect(find.text('MARKINGS'), findsNothing);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('Pt'), findsOneWidget);
    expect(find.text('Pd'), findsOneWidget);
    expect(find.text('Rh'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('2/2'), findsOneWidget);
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
  ConverterDraft? createdDraft;

  @override
  Future<String> uploadConverterImage({
    required List<int> bytes,
    required String fileName,
  }) async => '';

  @override
  Future<int> createConverter(ConverterDraft draft) async {
    createdDraft = draft;
    return 0;
  }

  @override
  Future<void> updateConverter(int converterId, ConverterDraft draft) async {}

  @override
  Future<void> deleteConverter(int converterId) async {}

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
      converterCode: 'AUTO-$converterId',
      brandId: 2,
      brandName: 'Suzuki',
      model: 'Swift',
      country: 'India',
      images: const [
        'https://example.com/converter.png',
        'https://example.com/converter-back.png',
      ],
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
  _FakeBrandService({this.converterBrands});

  final List<CarBrand>? converterBrands;

  @override
  Future<List<CarBrand>> getBrands({bool forceRefresh = false}) async =>
      const [];

  @override
  Future<List<CarBrand>> getConverterBrands({bool forceRefresh = false}) async {
    return converterBrands ??
        const [CarBrand(id: 2, slug: 'suzuki', name: 'Suzuki', logoUrl: null)];
  }
}

class _FakeAuthenticatedApiClient implements AuthenticatedApiClient {
  _FakeAuthenticatedApiClient({required this.responseData});

  final dynamic responseData;
  final requestedPaths = <String>[];
  final requestedMethods = <String>[];
  final requestedData = <Object?>[];
  final requestedQueryParameters = <Map<String, dynamic>>[];

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    requestedPaths.add(path);
    requestedQueryParameters.add(queryParameters ?? const {});
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
  Future<Response<dynamic>> patch(String path, {Object? data}) {
    requestedPaths.add(path);
    requestedMethods.add('PATCH');
    requestedData.add(data);
    return Future.value(
      Response<dynamic>(requestOptions: RequestOptions(path: path)),
    );
  }

  @override
  Future<Response<dynamic>> delete(String path) {
    requestedPaths.add(path);
    requestedMethods.add('DELETE');
    return Future.value(
      Response<dynamic>(requestOptions: RequestOptions(path: path)),
    );
  }

  @override
  Future<Options> createAuthorizedOptions() {
    throw UnimplementedError();
  }
}
