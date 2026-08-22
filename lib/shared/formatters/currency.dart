import "package:intl/intl.dart";

String formatMinor(int minor, {String currency = "USD"}) =>
    NumberFormat.currency(
      symbol: "$currency ",
      decimalDigits: 2,
    ).format(minor / 100);
