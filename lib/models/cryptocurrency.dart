import 'package:intl/intl.dart';

class Cryptocurrency {
  final String id;
  final String name;
  final String symbol;
  final String image;
  final String? iconUrl;
  final double currentPrice;
  final double priceChangePercentage24h;
  final double high24h;
  final double low24h;
  final double marketCap;
  final double volume24h;
  final List<double> sparklineData;

  const Cryptocurrency({
    required this.id,
    required this.name,
    required this.symbol,
    required this.image,
    this.iconUrl,
    this.currentPrice = 0,
    this.priceChangePercentage24h = 0,
    this.high24h = 0,
    this.low24h = 0,
    this.marketCap = 0,
    this.volume24h = 0,
    this.sparklineData = const [],
  });

  bool get isPriceUp => priceChangePercentage24h >= 0;

  String get formattedPrice => NumberFormat.currency(
        symbol: '\$',
        decimalDigits: currentPrice < 1 ? 4 : 2,
      ).format(currentPrice);

  String get formattedPriceChange {
    final sign = isPriceUp ? '+' : '';
    return '$sign${priceChangePercentage24h.toStringAsFixed(2)}%';
  }

  /// Static coin metadata for the assets the backend actually trades
  /// (`backend/src/services/exchange.js` SUPPORTED list, minus USDT since
  /// it's the quote asset, not something users buy/sell). `id`/`symbol`
  /// match the asset code the `/trade` endpoints expect.
  static const List<Cryptocurrency> assets = [
    Cryptocurrency(id: 'BTC', name: 'Bitcoin', symbol: 'BTC', image: 'assets/icons/btc.png'),
    Cryptocurrency(id: 'ETH', name: 'Ethereum', symbol: 'ETH', image: 'assets/icons/eth.png'),
    Cryptocurrency(id: 'BNB', name: 'BNB', symbol: 'BNB', image: 'assets/icons/bnb.png'),
    Cryptocurrency(id: 'SOL', name: 'Solana', symbol: 'SOL', image: 'assets/icons/sol.png'),
    Cryptocurrency(id: 'ADA', name: 'Cardano', symbol: 'ADA', image: 'assets/icons/ada.png'),
  ];

  /// Merges live prices (the `assets` map from `ApiService.market()`, keyed
  /// by symbol) onto the static metadata above. Coins missing live data
  /// keep their zeroed defaults rather than showing a fabricated number.
  static List<Cryptocurrency> withLiveData(Map<String, dynamic>? marketAssets) {
    if (marketAssets == null) return assets;
    return assets.map((coin) {
      final live = marketAssets[coin.symbol] as Map<String, dynamic>?;
      if (live == null) return coin;
      final price = (live['price'] as num?)?.toDouble() ?? 0;
      final low = (live['low24h'] as num?)?.toDouble() ?? price;
      final high = (live['high24h'] as num?)?.toDouble() ?? price;
      return Cryptocurrency(
        id: coin.id,
        name: coin.name,
        symbol: coin.symbol,
        image: coin.image,
        iconUrl: live['iconUrl'] as String?,
        currentPrice: price,
        priceChangePercentage24h: (live['change24h'] as num?)?.toDouble() ?? 0,
        high24h: high,
        low24h: low,
        volume24h: (live['volume24h'] as num?)?.toDouble() ?? 0,
        // Grounded in the real low/current/high rather than fabricated —
        // just enough points for the existing mini trend chart to draw.
        sparklineData: [low, price, high],
      );
    }).toList();
  }

  // Sample data for the trading detail screen, which manages its own
  // (currently mock) chart/selection state — left untouched here.
  static List<Cryptocurrency> mockData = [
    Cryptocurrency(
      id: 'bitcoin',
      name: 'Bitcoin',
      symbol: 'BTC',
      image: 'assets/icons/btc.png',
      currentPrice: 64253.21,
      priceChangePercentage24h: 2.34,
      high24h: 65102.34,
      low24h: 63021.56,
      marketCap: 1258000000000,
      volume24h: 28500000000,
      sparklineData: [
        63200,
        63400,
        63900,
        64100,
        64300,
        64200,
        64250,
        64100,
        64050,
        64200,
        64300,
        64250,
      ],
    ),
    Cryptocurrency(
      id: 'ethereum',
      name: 'Ethereum',
      symbol: 'ETH',
      image: 'assets/icons/eth.png',
      currentPrice: 3456.78,
      priceChangePercentage24h: -1.25,
      high24h: 3521.45,
      low24h: 3412.34,
      marketCap: 417000000000,
      volume24h: 15300000000,
      sparklineData: [
        3510,
        3490,
        3470,
        3450,
        3430,
        3440,
        3460,
        3450,
        3440,
        3450,
        3460,
        3456,
      ],
    ),
    Cryptocurrency(
      id: 'binancecoin',
      name: 'BNB',
      symbol: 'BNB',
      image: 'assets/icons/bnb.png',
      currentPrice: 612.34,
      priceChangePercentage24h: 3.78,
      high24h: 615.67,
      low24h: 589.23,
      marketCap: 94300000000,
      volume24h: 2120000000,
      sparklineData: [
        590,
        595,
        600,
        605,
        610,
        608,
        612,
        614,
        612,
        611,
        612,
        612,
      ],
    ),
    Cryptocurrency(
      id: 'solana',
      name: 'Solana',
      symbol: 'SOL',
      image: 'assets/icons/sol.png',
      currentPrice: 143.21,
      priceChangePercentage24h: 5.67,
      high24h: 144.56,
      low24h: 135.78,
      marketCap: 62500000000,
      volume24h: 3450000000,
      sparklineData: [
        136,
        138,
        140,
        139,
        141,
        142,
        143,
        142,
        143,
        142,
        143,
        143,
      ],
    ),
    Cryptocurrency(
      id: 'cardano',
      name: 'Cardano',
      symbol: 'ADA',
      image: 'assets/icons/ada.png',
      currentPrice: 0.45,
      priceChangePercentage24h: -2.34,
      high24h: 0.47,
      low24h: 0.44,
      marketCap: 16000000000,
      volume24h: 542000000,
      sparklineData: [
        0.47,
        0.46,
        0.45,
        0.44,
        0.45,
        0.46,
        0.45,
        0.44,
        0.45,
        0.45,
        0.45,
        0.45,
      ],
    ),
  ];
}
