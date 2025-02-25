class Transaction {
  final double amount;
  final String description;
  final DateTime date;
  final String? reference;
  final bool isIncoming;

  Transaction({
    required this.amount,
    required this.description,
    required this.date,
    this.reference,
    required this.isIncoming,
  });

  factory Transaction.fromSms(String sms, {required DateTime messageDate}) {
    final isIncoming = sms.contains('received') || sms.contains('have received');
    final amount = _extractAmount(sms);
    final reference = _extractReference(sms);
    
    return Transaction(
      amount: amount,
      description: _generateDescription(sms),
      date: messageDate,
      reference: reference,
      isIncoming: isIncoming,
    );
  }

  static double _extractAmount(String sms) {
    final regex = RegExp(r'(\d+,?\d*) RWF');
    final match = regex.firstMatch(sms);
    if (match == null) return 0;
    return double.parse(match.group(1)!.replaceAll(',', ''));
  }

  static String? _extractReference(String sms) {
    final regex = RegExp(r'Id: (\d+)');
    final match = regex.firstMatch(sms);
    return match?.group(1);
  }

  static String _generateDescription(String sms) {
    // Extract the main transaction description
    // This is a simple implementation - you might want to enhance it
    return sms.split('.')[0];
  }
} 