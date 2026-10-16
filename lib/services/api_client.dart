import 'package:dio/dio.dart';

// Por defecto usa el backend de Render. Para usar el backend en local:
//   flutter run --dart-define=API_URL=http://<IP-de-tu-PC>:8000/api/v1
// En emulador Android: 10.0.2.2 apunta a localhost de tu PC
const String kBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://sellin-backend.onrender.com/api/v1',
);

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio _dio;

  /// Token JWT de la sesión actual; lo gestiona AuthController.
  String? token;

  /// Se llama cuando el backend responde 401 (token caducado o inválido).
  void Function()? onUnauthorized;

  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: kBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (error, handler) {
        final isAuthCall = error.requestOptions.path.startsWith('/auth/');
        if (error.response?.statusCode == 401 && !isAuthCall) onUnauthorized?.call();
        handler.next(error);
      },
    ));

    _dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
    ));
  }

  // ─── Auth ────────────────────────────────────────────────────────────────────

  /// Devuelve el token JWT. Lanza [AuthException] con un mensaje para el usuario.
  Future<String> login(String email, String password) =>
      _authRequest('/auth/login', email, password);

  Future<String> register(String email, String password) =>
      _authRequest('/auth/register', email, password);

  /// Cambia el ID token de Google por nuestro token JWT.
  Future<String> loginWithGoogle(String idToken) =>
      _authRequest('/auth/google', null, null, idToken: idToken);

  Future<String> _authRequest(
    String path,
    String? email,
    String? password, {
    String? idToken,
  }) async {
    final data = idToken != null
        ? {'id_token': idToken}
        : {'email': email, 'password': password};
    try {
      final response = await _dio.post(path, data: data);
      return response.data['access_token'] as String;
    } on DioException catch (e) {
      throw AuthException(_authErrorMessage(e));
    }
  }

  String _authErrorMessage(DioException e) {
    final response = e.response;
    if (response == null) return 'No se puede conectar con el servidor';
    final detail = response.data is Map ? response.data['detail'] : null;
    if (detail is String) return detail;
    if (response.statusCode == 422) {
      return 'Revisa el email y usa una contraseña de al menos 8 caracteres';
    }
    return 'Error inesperado (${response.statusCode})';
  }

  Future<List<Signal>> getSignals({
    String? signalType,
    String? strength,
    bool clusterOnly = false,
    bool sortByScore = false,
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
      'sort': sortByScore ? 'score' : 'recent',
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

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
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
