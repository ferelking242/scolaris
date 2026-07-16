import 'package:intl/intl.dart';

class SbInvoiceForPrint {
  final String invoiceNumber;
  final String studentName;
  final String description;
  final double amount;
  final String currency;
  final bool isPaid;

  const SbInvoiceForPrint({
    required this.invoiceNumber,
    required this.studentName,
    required this.description,
    required this.amount,
    required this.currency,
    required this.isPaid,
  });

  String get amountFormatted => NumberFormat.compact(locale: 'fr').format(amount);
}
