import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:malik/core/theme/app_colors.dart';
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
import 'package:malik/services/converter_image_validator.dart';
import 'package:malik/services/converter_import_parser.dart';
import 'package:malik/services/persistent_converter_catalog_cache.dart';
import 'package:malik/services/converter_service.dart';
import 'package:malik/services/authenticated_api_client.dart';
import 'package:malik/widgets/profile/converter_form_sheet.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'parses converter rows and cursor metadata from the catalogue response',
    () {
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
          'next_cursor': 41,
          'has_more': true,
          'page_size': 20,
        },
        brandsById: const {8: 'Suzuki'},
      );

      expect(result.hasMore, isTrue);
      expect(result.nextCursor, '41');
      expect(result.converters.single.id, 42);
      expect(result.converters.single.converterCode, '420042');
      expect(result.converters.single.brandName, 'Suzuki');
      expect(result.converters.single.model, 'Swift');
      expect(result.converters.single.images, [
        'https://example.com/converter.png',
      ]);
    },
  );

  test('catalog pages are reused until refresh or cache expiry', () {
    var now = DateTime(2026);
    final cache = ConverterCatalogCache(
      ttl: const Duration(minutes: 5),
      clock: () => now,
    );
    const page = ConverterCatalogPage(
      converters: [ConverterRecord(id: 1, codeReference: 'CAT-1')],
      hasMore: true,
      nextCursor: '1',
      pageSize: 20,
    );

    cache.write(
      search: '',
      brandId: null,
      pageSize: 20,
      cursor: null,
      revision: cache.revision(search: '', brandId: null, pageSize: 20),
      page: page,
    );
    expect(
      cache.read(search: '', brandId: null, pageSize: 20, cursor: null),
      same(page),
    );
    expect(
      cache.read(search: 'marking', brandId: null, pageSize: 20, cursor: null),
      isNull,
    );

    cache.invalidate(search: '', brandId: null, pageSize: 20);
    expect(
      cache.read(search: '', brandId: null, pageSize: 20, cursor: null),
      isNull,
    );

    cache.write(
      search: '',
      brandId: null,
      pageSize: 20,
      cursor: null,
      revision: cache.revision(search: '', brandId: null, pageSize: 20),
      page: page,
    );
    now = now.add(const Duration(minutes: 6));
    expect(
      cache.read(search: '', brandId: null, pageSize: 20, cursor: null),
      isNull,
    );
  });

  test(
    'the first catalogue page persists separately for each filter',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final cache = PersistentConverterCatalogCache(preferences: preferences);
      const page = ConverterCatalogPage(
        converters: [
          ConverterRecord(
            id: 42,
            codeReference: 'ABC-42',
            brandId: 8,
            brandName: 'Suzuki',
          ),
        ],
        hasMore: true,
        nextCursor: '43',
        pageSize: 20,
      );

      await cache.write(
        search: 'catalyst',
        brandId: 8,
        pageSize: 20,
        page: page,
      );

      final restored = await cache.read(
        search: 'catalyst',
        brandId: 8,
        pageSize: 20,
        brandsById: const {8: 'Suzuki'},
      );
      final anotherFilter = await cache.read(
        search: 'catalyst',
        brandId: 9,
        pageSize: 20,
        brandsById: const {},
      );

      expect(restored?.isFresh, isTrue);
      expect(restored?.page.converters.single.codeReference, 'ABC-42');
      expect(anotherFilter, isNull);
    },
  );

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

  test('bulk converter import uses the protected atomic endpoint', () async {
    final apiClient = _FakeAuthenticatedApiClient(
      responseData: {
        'converter_ids': [40, 41],
        'count': 2,
      },
    );
    final service = ConverterService(
      apiClient: apiClient,
      catalogCache: ConverterCatalogCache(),
    );
    const drafts = [
      ConverterDraft(brandId: 8, codeReference: 'ABC-40'),
      ConverterDraft(brandId: 8, codeReference: 'ABC-41'),
    ];

    final ids = await service.createConvertersBulk(drafts);

    expect(ids, [40, 41]);
    expect(apiClient.requestedPaths, [ApiConstants.bulkConverters]);
    expect(apiClient.requestedMethods, ['POST']);
    expect(apiClient.requestedData.single, {
      'converters': [for (final draft in drafts) draft.toJson()],
    });
  });

  test(
    'image validation only accepts supported formats within the size limit',
    () {
      expect(
        () => ConverterImageValidator.validate(
          bytes: Uint8List.fromList([0xff, 0xd8, 0xff, 0x00]),
          fileName: 'converter.jpg',
        ),
        returnsNormally,
      );
      expect(
        () => ConverterImageValidator.validate(
          bytes: Uint8List.fromList([0x00, 0x01]),
          fileName: 'not-an-image.txt',
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'bulk parser rejects oversize files before attempting to parse them',
    () {
      final preview = ConverterImportParser().parse(
        PlatformFile(
          name: 'too-large.csv',
          size: ConverterImportParser.maxFileBytes + 1,
          bytes: Uint8List.fromList(
            utf8.encode('brand_id,code_reference\n1,A'),
          ),
        ),
      );

      expect(preview.isReady, isFalse);
      expect(preview.errors.single, 'Import files must be 2 MB or smaller.');
    },
  );

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
      responseData: {
        'items': [],
        'next_cursor': null,
        'has_more': false,
        'page_size': 20,
      },
    );
    final service = ConverterService(
      apiClient: apiClient,
      catalogCache: ConverterCatalogCache(),
    );

    await service.getConverters(brandId: 87, forceRefresh: true);

    expect(apiClient.requestedQueryParameters.single['brand_id'], 87);
  });

  test('converter API uses cursor pagination and never sends page', () async {
    final apiClient = _FakeAuthenticatedApiClient(
      responseData: {
        'items': [],
        'next_cursor': null,
        'has_more': false,
        'page_size': 20,
      },
    );
    final service = ConverterService(
      apiClient: apiClient,
      catalogCache: ConverterCatalogCache(),
    );

    await service.getConverters(
      search: 'catalyst',
      cursor: '43',
      forceRefresh: true,
    );

    expect(apiClient.requestedQueryParameters.single, {
      'page_size': 20,
      'cursor': '43',
      'search': 'catalyst',
    });
  });

  test('converter API rejects invalid client-side search terms', () async {
    final service = ConverterService(
      apiClient: _FakeAuthenticatedApiClient(responseData: const {}),
      catalogCache: ConverterCatalogCache(),
    );

    await expectLater(
      service.getConverters(search: 'ab'),
      throwsA(isA<ArgumentError>()),
    );
    await expectLater(
      service.getConverters(search: List.filled(101, 'a').join()),
      throwsA(isA<ArgumentError>()),
    );
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
                  logoUrl: null,
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

  testWidgets('catalog requests more pages with the next cursor', (
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

    expect(find.text('20+ converters'), findsOneWidget);
    expect(find.text('CAT-1'), findsOneWidget);
    expect(service.requestedCursors, [null]);

    for (var attempt = 0; attempt < 4; attempt++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
      await tester.pump();
    }
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
    await tester.pumpAndSettle();

    expect(service.requestedCursors, [null, '20']);
  });

  testWidgets('catalog converter thumbnail uses enlarged size', (tester) async {
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
      tester
          .getSize(find.byKey(const ValueKey('catalog-converter-image')).first)
          .width,
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

    expect(service.queries.single.cursor, isNull);
    expect(find.text('20+ converters'), findsOneWidget);
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

  testWidgets('converter detail uses a full-bleed swipeable image hero', (
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
      (widget) => widget is Image && widget.fit == BoxFit.cover,
    );
    expect(heroImage, findsOneWidget);
    expect(tester.getSize(heroImage).width, 400);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('converter-detail-image-hero')))
          .height,
      336,
    );
    expect(find.byType(PageView), findsOneWidget);
    expect(find.byTooltip('Previous image'), findsNothing);
    expect(find.byTooltip('Next image'), findsNothing);
    expect(find.text('ID  AUTO-1'), findsOneWidget);
    expect(find.text('Swift'), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.text('ID  AUTO-1')).dy,
      greaterThan(
        tester
            .getBottomLeft(
              find.byKey(const ValueKey('converter-detail-image-hero')),
            )
            .dy,
      ),
    );
    expect(find.text('1/2'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('converter-detail-image-hero')),
      const Offset(-250, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('2/2'), findsOneWidget);
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
      expect(service.queries.last.search, '86J C04');

      final matchingCodes = tester.widgetList<RichText>(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText && widget.text.toPlainText() == '86J C04',
        ),
      );
      int goldHighlightCount(InlineSpan span) {
        if (span is! TextSpan) return 0;
        return (span.style?.backgroundColor == AppColors.accent ? 1 : 0) +
            (span.children?.fold<int>(
                  0,
                  (count, child) => count + goldHighlightCount(child),
                ) ??
                0);
      }

      expect(
        matchingCodes.any((text) => goldHighlightCount(text.text) == 2),
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

    await tester.tap(find.text('Suzuki').first);
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

    await tester.tap(find.text('Suzuki').first);
    await tester.pumpAndSettle();
    expect(service.queries.last.brandId, 2);

    await tester.enterText(find.byType(TextField), '86J C04');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(service.queries.last.search, '86J C04');
    expect(service.queries.last.brandId, 2);
    expect(service.queries.last.cursor, isNull);
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
    expect(find.text('PLATINUM'), findsOneWidget);
    expect(find.text('PALLADIUM'), findsOneWidget);
    expect(find.text('RHODIUM'), findsOneWidget);
    expect(find.byTooltip('Next image'), findsNothing);
    await tester.drag(
      find.byKey(const ValueKey('converter-detail-image-hero')),
      const Offset(-250, 0),
    );
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
    expect(find.byType(TextField), findsOneWidget);
    expect(service.queries, isEmpty);
    expect(find.text('CAT-1'), findsNothing);
    expect(find.text('40 converters'), findsNothing);

    await tester.enterText(find.byType(TextField), '86J C04');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(service.queries.last.search, '86J C04');
    expect(service.queries.last.cursor, isNull);
    expect(find.text('2 converters'), findsOneWidget);
    expect(find.text('CAT-1'), findsOneWidget);

    await tester.enterText(find.byType(TextField), ' ');
    await tester.pump();
    expect(find.text('CAT-1'), findsNothing);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(service.queries, hasLength(1));
  });

  testWidgets('short and overlong search terms do not call the catalogue API', (
    tester,
  ) async {
    final service = _FakeConverterService();
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

    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump(const Duration(milliseconds: 400));
    expect(service.queries, isEmpty);
    expect(find.text('Enter at least 3 characters to search.'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      List.filled(101, 'a').join(),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(service.queries, isEmpty);
    expect(
      find.text('Search terms can be at most 100 characters.'),
      findsOneWidget,
    );
  });
}

class _FakeConverterService implements ConverterService {
  final requestedCursors = <String?>[];
  final queries = <({String? cursor, String? search, int? brandId})>[];
  final requestedDetails = <int>[];
  ConverterDraft? createdDraft;

  @override
  Future<CachedConverterCatalogPage?> getCachedFirstPage({
    int pageSize = 20,
    String? search,
    int? brandId,
    Map<int, String> brandsById = const {},
  }) async => null;

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
  Future<List<int>> createConvertersBulk(List<ConverterDraft> drafts) async =>
      List<int>.generate(drafts.length, (index) => index + 1);

  @override
  Future<void> updateConverter(int converterId, ConverterDraft draft) async {}

  @override
  Future<void> deleteConverter(int converterId) async {}

  @override
  String messageFor(Object error) => 'Request failed.';

  @override
  Future<ConverterCatalogPage> getConverters({
    int pageSize = 20,
    String? cursor,
    String? search,
    int? brandId,
    Map<int, String> brandsById = const {},
    bool forceRefresh = false,
  }) async {
    requestedCursors.add(cursor);
    queries.add((cursor: cursor, search: search, brandId: brandId));
    final total = search == null || search.isEmpty ? 40 : 2;
    final start = cursor == null ? 0 : int.parse(cursor);
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
      hasMore: start + count < total,
      nextCursor: start + count < total ? '${start + count}' : null,
      pageSize: pageSize,
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
  Future<List<CarBrand>?> getCachedConverterBrands() async => null;

  @override
  Future<List<CarBrand>> getBrands({bool forceRefresh = false}) async =>
      const [];

  @override
  Future<List<CarBrand>> getConverterBrands({bool forceRefresh = false}) async {
    return converterBrands ??
        const [
          CarBrand(
            id: 2,
            slug: 'suzuki',
            name: 'Suzuki',
            logoUrl: 'https://example.com/suzuki.png',
          ),
        ];
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
    Duration? receiveTimeout,
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
    requestedPaths.add(path);
    requestedMethods.add('POST');
    requestedData.add(data);
    return Future.value(
      Response<dynamic>(
        requestOptions: RequestOptions(path: path),
        data: responseData,
      ),
    );
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
