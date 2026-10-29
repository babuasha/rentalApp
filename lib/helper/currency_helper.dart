import 'dart:convert';
import 'package:http/http.dart' as http;

class CurrencyHelper {
  // Default exchange rates relative to OMR base currency (1 OMR = X Currency)
  Map<String, double> _exchangeRates = {
    'OMR': 1.0,
    'AED': 9.52,
    'USD': 2.60,
    'SAR': 9.75,
    'KWD': 0.79,
    'BHD': 0.98,
    'EUR': 2.38,
    'GBP': 2.04,
    'INR': 217.39,
    'THB': 88.50,
    'TRY': 127.95,
    'XCD': 7.03, // St. Kitts & Nevis East Caribbean Dollar
    'LBP': 234000.0 // Lebanon Lebanese Pound fallback
  };

  Map<String, double> get exchangeRates => _exchangeRates;

  /// Fetch real-time exchange rates via REST API using standard http library
  Future<Map<String, double>> fetchExchangeRates() async {
    try {
      final response = await http.get(
        Uri.parse('https://open.er-api.com/v6/latest/OMR'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['rates'] != null) {
          final Map<String, dynamic> rates = data['rates'];
          _exchangeRates = rates.map(
            (key, value) => MapEntry(key, (value as num).toDouble()),
          );
        }
      }
    } catch (_) {
      // Fallback to cached default exchange rates on error
    }
    return _exchangeRates;
  }

  /// Maps country identifier or text to ISO currency code
  String getCurrencyCode(String countryOrCurrency) {
    final key = countryOrCurrency.toUpperCase().trim();

    if (key.contains('OMAN') || key.contains('OMR')) return 'OMR';
    if (key.contains('UAE') || key.contains('AED') || key.contains('DUBAI') || key.contains('UNITED ARAB EMIRATES') || key.contains('UNITED ARAB')) return 'AED';
    if (key.contains('USA') || key.contains('USD') || key.contains('DOLLAR')) return 'USD';
    if (key.contains('SAUDI') || key.contains('SAR')) return 'SAR';
    if (key.contains('KUWAIT') || key.contains('KWD')) return 'KWD';
    if (key.contains('BAHRAIN') || key.contains('BHD')) return 'BHD';
    if (key.contains('EURO') || key.contains('EUR')) return 'EUR';
    if (key.contains('UNITED KINGDOM') || key.contains('GBP')) return 'GBP';
    if (key.contains('INDIA') || key.contains('INR')) return 'INR';
    if (key.contains('THAILAND') || key.contains('THB')) return 'THB';
    if (key.contains('TURKEY') || key.contains('TRY')) return 'TRY';
    
    // Added explicit match conditions for St. Kitts & Lebanon
    if (key.contains('ST. KITTS') || key.contains('ST KITTS') || key.contains('KITTS') || key.contains('XCD')) return 'XCD';
    if (key.contains('LEBANON') || key.contains('LEBANESE') || key.contains('LBP')) return 'LBP';

    if (key.length == 3) return key;

    return 'OMR';
  }

  /// Converts target currency amount into OMR using fetched/cached exchange rates
  double convertToOMR(double amount, String countryOrCurrency) {
    final currencyCode = getCurrencyCode(countryOrCurrency);

    if (currencyCode == 'OMR') return amount;

    final rate = _exchangeRates[currencyCode];
    if (rate != null && rate > 0) {
      return amount / rate;
    }

    return amount;
  }
}