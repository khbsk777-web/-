import 'package:uuid/uuid.dart';

enum ProductCondition {
  brandNew('新品・未使用', 'S'),
  likeNew('未使用に近い', 'A+'),
  good('目立った傷や汚れなし', 'A'),
  fair('やや傷や汚れあり', 'B'),
  poor('傷や汚れあり', 'C'),
  bad('全体的に状態が悪い', 'D');

  const ProductCondition(this.label, this.rank);
  final String label;
  final String rank;
}

enum ProductCategory {
  clothing('ファッション'),
  shoes('靴・スニーカー'),
  bags('バッグ・小物'),
  electronics('家電・スマホ'),
  hobbies('おもちゃ・ホビー'),
  sports('スポーツ・レジャー'),
  beauty('コスメ・美容'),
  books('本・漫画'),
  games('ゲーム'),
  furniture('家具・インテリア'),
  food('食品・飲料'),
  other('その他');

  const ProductCategory(this.label);
  final String label;
}

enum ListingStatus {
  draft('下書き'),
  listed('出品中'),
  sold('売却済み'),
  cancelled('取り消し');

  const ListingStatus(this.label);
  final String label;
}

class PlatformPrice {
  final String platform;
  final int? price;
  final String? listingUrl;
  final DateTime? listedAt;
  final bool isSold;

  const PlatformPrice({
    required this.platform,
    this.price,
    this.listingUrl,
    this.listedAt,
    this.isSold = false,
  });

  PlatformPrice copyWith({
    int? price,
    String? listingUrl,
    DateTime? listedAt,
    bool? isSold,
  }) {
    return PlatformPrice(
      platform: platform,
      price: price ?? this.price,
      listingUrl: listingUrl ?? this.listingUrl,
      listedAt: listedAt ?? this.listedAt,
      isSold: isSold ?? this.isSold,
    );
  }

  Map<String, dynamic> toMap() => {
        'platform': platform,
        'price': price,
        'listingUrl': listingUrl,
        'listedAt': listedAt?.millisecondsSinceEpoch,
        'isSold': isSold ? 1 : 0,
      };

  factory PlatformPrice.fromMap(Map<String, dynamic> map) => PlatformPrice(
        platform: map['platform'] as String,
        price: map['price'] as int?,
        listingUrl: map['listingUrl'] as String?,
        listedAt: map['listedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['listedAt'] as int)
            : null,
        isSold: (map['isSold'] as int?) == 1,
      );
}

class Product {
  final String id;
  final String name;
  final String description;
  final ProductCategory category;
  final ProductCondition condition;
  final int purchasePrice;
  final List<String> imagePaths;
  final PlatformPrice mercariPrice;
  final PlatformPrice rakumaPrice;
  final ListingStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? memo;
  final List<String> tags;

  Product({
    String? id,
    required this.name,
    this.description = '',
    required this.category,
    required this.condition,
    this.purchasePrice = 0,
    this.imagePaths = const [],
    PlatformPrice? mercariPrice,
    PlatformPrice? rakumaPrice,
    this.status = ListingStatus.draft,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.memo,
    this.tags = const [],
  })  : id = id ?? const Uuid().v4(),
        mercariPrice = mercariPrice ?? const PlatformPrice(platform: 'メルカリ'),
        rakumaPrice = rakumaPrice ?? const PlatformPrice(platform: 'ラクマ'),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  int? get bestPrice {
    final prices = [mercariPrice.price, rakumaPrice.price]
        .whereType<int>()
        .toList();
    if (prices.isEmpty) return null;
    return prices.reduce((a, b) => a > b ? a : b);
  }

  String? get bestPlatform {
    if (mercariPrice.price == null && rakumaPrice.price == null) return null;
    if (mercariPrice.price == null) return 'ラクマ';
    if (rakumaPrice.price == null) return 'メルカリ';
    return mercariPrice.price! >= rakumaPrice.price! ? 'メルカリ' : 'ラクマ';
  }

  int? get profit {
    final best = bestPrice;
    if (best == null) return null;
    return best - purchasePrice;
  }

  double? get profitRate {
    final p = profit;
    if (p == null || purchasePrice == 0) return null;
    return p / purchasePrice * 100;
  }

  Product copyWith({
    String? name,
    String? description,
    ProductCategory? category,
    ProductCondition? condition,
    int? purchasePrice,
    List<String>? imagePaths,
    PlatformPrice? mercariPrice,
    PlatformPrice? rakumaPrice,
    ListingStatus? status,
    String? memo,
    List<String>? tags,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      condition: condition ?? this.condition,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      imagePaths: imagePaths ?? this.imagePaths,
      mercariPrice: mercariPrice ?? this.mercariPrice,
      rakumaPrice: rakumaPrice ?? this.rakumaPrice,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      memo: memo ?? this.memo,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'category': category.name,
        'condition': condition.name,
        'purchasePrice': purchasePrice,
        'imagePaths': imagePaths.join('|||'),
        'mercariPrice': mercariPrice.price,
        'mercariUrl': mercariPrice.listingUrl,
        'mercariListedAt': mercariPrice.listedAt?.millisecondsSinceEpoch,
        'mercariSold': mercariPrice.isSold ? 1 : 0,
        'rakumaPrice': rakumaPrice.price,
        'rakumaUrl': rakumaPrice.listingUrl,
        'rakumaListedAt': rakumaPrice.listedAt?.millisecondsSinceEpoch,
        'rakumaSold': rakumaPrice.isSold ? 1 : 0,
        'status': status.name,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'memo': memo,
        'tags': tags.join(','),
      };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String? ?? '',
        category: ProductCategory.values.firstWhere(
          (e) => e.name == map['category'],
          orElse: () => ProductCategory.other,
        ),
        condition: ProductCondition.values.firstWhere(
          (e) => e.name == map['condition'],
          orElse: () => ProductCondition.good,
        ),
        purchasePrice: map['purchasePrice'] as int? ?? 0,
        imagePaths: (map['imagePaths'] as String?)
                ?.split('|||')
                .where((s) => s.isNotEmpty)
                .toList() ??
            [],
        mercariPrice: PlatformPrice(
          platform: 'メルカリ',
          price: map['mercariPrice'] as int?,
          listingUrl: map['mercariUrl'] as String?,
          listedAt: map['mercariListedAt'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  map['mercariListedAt'] as int)
              : null,
          isSold: (map['mercariSold'] as int?) == 1,
        ),
        rakumaPrice: PlatformPrice(
          platform: 'ラクマ',
          price: map['rakumaPrice'] as int?,
          listingUrl: map['rakumaUrl'] as String?,
          listedAt: map['rakumaListedAt'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  map['rakumaListedAt'] as int)
              : null,
          isSold: (map['rakumaSold'] as int?) == 1,
        ),
        status: ListingStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => ListingStatus.draft,
        ),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            map['createdAt'] as int? ?? 0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
            map['updatedAt'] as int? ?? 0),
        memo: map['memo'] as String?,
        tags: (map['tags'] as String?)
                ?.split(',')
                .where((s) => s.isNotEmpty)
                .toList() ??
            [],
      );
}
