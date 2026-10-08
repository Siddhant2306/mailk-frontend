import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:malik/screens/home.dart';
import 'package:malik/widgets/home/metal_price_grid.dart';
import 'package:malik/models/market_models.dart';
import 'package:malik/models/metal_price.dart';
import 'package:malik/models/car_brand.dart';
import 'package:malik/models/app_user.dart';
import 'package:malik/models/converter_draft.dart';
import 'package:malik/models/pending_user.dart';
import 'package:malik/services/admin_user_service.dart';
import 'package:malik/services/brand_service.dart';
import 'package:malik/services/metal_service.dart';
import 'package:malik/services/market_cache.dart';

void main() {
  test('converts ounce prices to kilograms', () {
    final price = MetalPrice(timestamp: 1704067200, price: 31.1034768);

    expect(price.pricePerKilo, closeTo(1000, 0.0001));
    expect(price.recordedAt.year, 2024);
  });

  test('uses request metadata when a quote omits symbol and currency', () {
    final quote = MetalLivePrice.fromJson(
      {'price': '1000.50'},
      fallbackSymbol: 'PT',
      fallbackCurrency: 'USD',
    );

    expect(quote.symbol, 'PT');
    expect(quote.currency, 'USD');
    expect(quote.price, 1000.50);
  });

  test('stores and restores fresh INR quotes locally', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = MarketCache();
    final quotes = {
      MetalType.platinum: MetalLivePrice(
        symbol: 'PT',
        currency: 'INR',
        price: 100000,
      ),
      MetalType.palladium: null,
      MetalType.rhodium: null,
    };

    await cache.writeQuotes(PriceUnit.inr, quotes);
    final restored = await cache.readQuotes(PriceUnit.inr);

    expect(restored?[MetalType.platinum]?.price, 100000);
    expect(restored?[MetalType.platinum]?.currency, 'INR');
  });

  test('reads a brand API record with its optional logo', () {
    final brand = CarBrand.fromJson({
      'slug': 'suzuki',
      'name': 'Suzuki',
      'logo': 'https://example.com/suzuki.png',
    });

    expect(brand.slug, 'suzuki');
    expect(brand.logoUrl, 'https://example.com/suzuki.png');
  });

  test('allows the profile tools only for an active approved admin', () {
    final admin = AppUser.fromJson({
      'id': 1,
      'email': 'admin@example.com',
      'name': 'Admin',
      'role': 'admin',
      'status': 'approved',
      'is_active': true,
    });
    final inactiveAdmin = AppUser.fromJson({
      'id': 2,
      'email': 'inactive@example.com',
      'name': '',
      'role': 'admin',
      'status': 'approved',
      'is_active': false,
    });

    expect(admin.isAdmin, isTrue);
    expect(inactiveAdmin.isAdmin, isFalse);
  });

  test('filters admin user list to pending approvals', () {
    final users = PendingUser.pendingFromResponse([
      {
        'id': 7,
        'name': 'Waiting Member',
        'email': 'waiting@example.com',
        'status': 'pending',
      },
      {
        'id': 8,
        'name': 'Approved Member',
        'email': 'approved@example.com',
        'status': 'approved',
      },
    ]);

    expect(users, hasLength(1));
    expect(users.single.id, 7);
    expect(users.single.displayName, 'Waiting Member');
  });

  test('serializes a converter using the backend field names', () {
    const draft = ConverterDraft(
      brandId: 12,
      codeReference: 'ABC-123',
      ptPpm: 900.5,
      markings: ['A1'],
    );

    expect(draft.toJson(), {
      'brand_id': 12,
      'code_reference': 'ABC-123',
      'pt_ppm': 900.5,
      'markings': ['A1'],
      'images': <String>[],
    });
  });

  testWidgets('keeps metal cards visible and lets the chart unit change', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          metalService: _FakeMetalService(),
          brandService: _FakeBrandService(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Platinum'), findsOneWidget);
    expect(find.text('Palladium'), findsOneWidget);
    expect(find.text('Rhodium'), findsOneWidget);
    expect(find.byType(MetalPriceCard), findsNWidgets(3));
    expect(find.text('₹32.15 L'), findsNWidgets(3));
    expect(find.text('Unavailable'), findsNothing);

    final cards = find.byType(MetalPriceCard);
    expect(tester.getRect(cards.at(0)).top, tester.getRect(cards.at(1)).top);
    expect(tester.getRect(cards.at(1)).top, tester.getRect(cards.at(2)).top);
    expect(tester.getRect(cards.at(2)).right, lessThanOrEqualTo(384));

    await tester.tap(find.text(r'$ / oz'));
    await tester.pump();

    expect(find.text(r'Platinum trend • $ / oz'), findsOneWidget);

    await tester.tap(find.text('Browse brands'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Brands'), findsOneWidget);
    expect(find.text('Suzuki'), findsOneWidget);
    expect(find.text('No Logo'), findsNothing);
    expect(find.text('TODO: converter details'), findsOneWidget);
  });

  testWidgets('shows the admin profile for an approved admin', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final admin = AppUser.fromJson({
      'id': 1,
      'email': 'admin@example.com',
      'name': 'Admin',
      'role': 'admin',
      'status': 'approved',
      'is_active': true,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          currentUser: admin,
          adminUserService: _FakeAdminUserService(),
          metalService: _FakeMetalService(),
          brandService: _FakeBrandService(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('PROFILE'));
    await tester.pump();

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('admin@example.com'), findsOneWidget);
    expect(find.text('Add converter'), findsOneWidget);
    expect(find.text('Admin profile'), findsNothing);
  });

  testWidgets('admin can approve a pending user and refresh the queue', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final admin = AppUser.fromJson({
      'id': 1,
      'email': 'admin@example.com',
      'name': 'Admin',
      'role': 'admin',
      'status': 'approved',
      'is_active': true,
    });
    final approvalService = _FakeAdminUserService(
      pendingUsers: [
        const PendingUser(id: 12, name: 'New Member', email: 'new@example.com'),
        const PendingUser(
          id: 13,
          name: 'Another Member',
          email: 'another@example.com',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          currentUser: admin,
          adminUserService: approvalService,
          metalService: _FakeMetalService(),
          brandService: _FakeBrandService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('PROFILE'));
    await tester.pumpAndSettle();

    expect(find.text('New Member'), findsOneWidget);
    expect(find.text('Approve'), findsNWidgets(2));
    expect(find.text('Reject'), findsNWidgets(2));

    await tester.tap(find.text('Approve').first);
    await tester.pumpAndSettle();

    expect(approvalService.approvedUserIds, [12]);
    expect(find.text('New Member'), findsNothing);
    expect(find.text('Another Member'), findsOneWidget);

    await tester.tap(find.text('Reject').first);
    await tester.pumpAndSettle();

    expect(approvalService.rejectedUserIds, [13]);
    expect(find.text('Another Member'), findsNothing);
    expect(find.text('Queue is clear'), findsOneWidget);
  });

  testWidgets('shows a normal profile without admin actions for a user', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final user = AppUser.fromJson({
      'id': 2,
      'email': 'user@example.com',
      'name': 'Regular User',
      'role': 'user',
      'status': 'approved',
      'is_active': true,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          currentUser: user,
          metalService: _FakeMetalService(),
          brandService: _FakeBrandService(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('PROFILE'));
    await tester.pump();

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Regular User'), findsOneWidget);
    expect(find.text('user@example.com'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Add converter'), findsNothing);
    expect(find.text('Bulk import · CSV / Excel'), findsNothing);
    expect(find.text('ADMIN ACTIONS'), findsNothing);
    expect(find.text('Admin profile'), findsNothing);
  });
}

class _FakeMetalService extends MetalService {
  @override
  Future<Map<MetalType, MetalLivePrice?>> getLiveQuotes({
    required PriceUnit unit,
    bool forceRefresh = false,
  }) async {
    final quotes = {
      for (final metal in MetalType.values)
        metal: MetalLivePrice(
          symbol: metal.apiSymbol,
          currency: unit.apiCurrency,
          price: unit == PriceUnit.inr ? 100000 : 1000,
          changePercentage: 1.5,
        ),
    };
    return quotes;
  }

  @override
  Future<Map<MetalType, List<MetalPrice>>> getHistoryForAllMetals({
    required int days,
    required PriceUnit unit,
    bool forceRefresh = false,
  }) async {
    final history = {
      for (final metal in MetalType.values)
        metal: [
          MetalPrice(timestamp: 1704067200, price: 900),
          MetalPrice(timestamp: 1704153600, price: 950),
          MetalPrice(timestamp: 1704240000, price: 1000),
        ],
    };
    return history;
  }

  @override
  Future<List<MetalPrice>> getHistoryForMetal({
    required MetalType metal,
    required int days,
    required PriceUnit unit,
    bool forceRefresh = false,
  }) async {
    return [
      MetalPrice(timestamp: 1704067200, price: 900),
      MetalPrice(timestamp: 1704153600, price: 950),
      MetalPrice(timestamp: 1704240000, price: 1000),
    ];
  }
}

class _FakeBrandService extends BrandService {
  @override
  Future<List<CarBrand>> getBrands({bool forceRefresh = false}) async {
    return const [
      CarBrand(slug: 'no-logo', name: 'No Logo', logoUrl: null),
      CarBrand(
        slug: 'suzuki',
        name: 'Suzuki',
        logoUrl: 'https://carimagesapi.com/makes/suzuki.png',
      ),
    ];
  }
}

class _FakeAdminUserService implements AdminUserService {
  _FakeAdminUserService({List<PendingUser> pendingUsers = const []})
    : _pendingUsers = List.of(pendingUsers);

  final List<PendingUser> _pendingUsers;
  final List<int> approvedUserIds = [];
  final List<int> rejectedUserIds = [];

  @override
  Future<List<PendingUser>> getPendingUsers() async => List.of(_pendingUsers);

  @override
  String messageFor(Object error) => 'Approval request failed.';

  @override
  Future<void> approveUser(int userId) async {
    approvedUserIds.add(userId);
    _pendingUsers.removeWhere((user) => user.id == userId);
  }

  @override
  Future<void> rejectUser(int userId) async {
    rejectedUserIds.add(userId);
    _pendingUsers.removeWhere((user) => user.id == userId);
  }
}
