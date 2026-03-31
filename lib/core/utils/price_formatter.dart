import 'package:intl/intl.dart';

final NumberFormat _currency = NumberFormat.currency(locale: 'fr_FR', symbol: '€');

String formatPriceEuro(num value) => _currency.format(value);
