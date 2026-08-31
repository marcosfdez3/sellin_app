import 'package:dio/dio.dart';

// Cambia esta URL cuando despliegues el backend
// En desarrollo: usa tu IP local si pruebas en dispositivo físico
// En emulador Android: 10.0.2.2 apunta a localhost de tu PC
const String kBaseUrl = 'https://sellin-backend.onrender.com';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio _dio;

  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: kBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
    ));
  }

  Future<List<Signal>> getSignals({
    String? signalType,
    String? strength,
    bool clusterOnly = false,
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
      if (signalType != null) 'signal_type': signalType,
      if (strength != null) 'strength': strength,
      if (clusterOnly) 'cluster_only': true,
    };

    final response = await _dio.get('/signals', queryParameters: params);
    final data = response.data as Map<String, dynamic>;
    final hits = data['signals'] as List;
    return hits.map((j) => Signal.fromJson(j)).toList();
  }

  Future<List<Transaction>> getTransactions({
    String? ticker,
    String? transactionType,
    int limit = 50,
  }) async {
    final params = <String, dynamic>{
      'limit': limit,
      if (ticker != null) 'ticker': ticker,
      if (transactionType != null) 'transaction_type': transactionType,
    };

    final response = await _dio.get('/transactions', queryParameters: params);
    final hits = response.data as List;
    return hits.map((j) => Transaction.fromJson(j)).toList();
  }

  Future<List<Transaction>> getCompanyTransactions(String ticker) async {
    final response = await _dio.get('/companies/$ticker/transactions');
    final hits = response.data as List;
    return hits.map((j) => Transaction.fromJson(j)).toList();
  }
}

// ─── Modelos ──────────────────────────────────────────────────────────────────

class Company {
  final int id;
  final String cik;
  final String? ticker;
  final String name;

  Company({required this.id, required this.cik, this.ticker, required this.name});

  factory Company.fromJson(Map<String, dynamic> j) => Company(
        id: j['id'],
        cik: j['cik'],
        ticker: j['ticker'],
        name: j['name'],
      );
}

class Signal {
  final int id;
  final Company company;
  final String signalType; // 'buy' | 'sell'
  final String strength;   // 'strong' | 'medium' | 'weak'
  final double score;
  final double totalValue;
  final int numInsiders;
  final bool isCluster;
  final String summary;
  final DateTime firstTransactionDate;
  final DateTime lastTransactionDate;
  final DateTime createdAt;

  Signal({
    required this.id,
    required this.company,
    required this.signalType,
    required this.strength,
    required this.score,
    required this.totalValue,
    required this.numInsiders,
    required this.isCluster,
    required this.summary,
    required this.firstTransactionDate,
    required this.lastTransactionDate,
    required this.createdAt,
  });

  factory Signal.fromJson(Map<String, dynamic> j) => Signal(
        id: j['id'],
        company: Company.fromJson(j['company']),
        signalType: j['signal_type'],
        strength: j['strength'],
        score: (j['score'] as num).toDouble(),
        totalValue: (j['total_value'] as num).toDouble(),
        numInsiders: j['num_insiders'],
        isCluster: j['is_cluster'],
        summary: j['summary'],
        firstTransactionDate: DateTime.parse(j['first_transaction_date']),
        lastTransactionDate: DateTime.parse(j['last_transaction_date']),
        createdAt: DateTime.parse(j['created_at']),
      );

  bool get isBuy => signalType == 'buy';
}

class Transaction {
  final int id;
  final Company company;
  final String transactionType;
  final String insiderRole;
  final double shares;
  final double? pricePerShare;
  final double? totalValue;
  final DateTime transactionDate;
  final String filingUrl;

  Transaction({
    required this.id,
    required this.company,
    required this.transactionType,
    required this.insiderRole,
    required this.shares,
    this.pricePerShare,
    this.totalValue,
    required this.transactionDate,
    required this.filingUrl,
  });

  factory Transaction.fromJson(Map<String, dynamic> j) => Transaction(
        id: j['id'],
        company: Company.fromJson(j['company']),
        transactionType: j['transaction_type'],
        insiderRole: j['insider_role'],
        shares: (j['shares'] as num).toDouble(),
        pricePerShare: j['price_per_share'] != null
            ? (j['price_per_share'] as num).toDouble()
            : null,
        totalValue: j['total_value'] != null
            ? (j['total_value'] as num).toDouble()
            : null,
        transactionDate: DateTime.parse(j['transaction_date']),
        filingUrl: j['filing_url'],
      );
}
