import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/transaction.dart';
import 'dart:developer' as developer;

class SmsService {
  static const platform = MethodChannel('com.example.momoapp/sms');

  Future<List<Transaction>> getTransactions() async {
    // Request SMS permissions
    final status = await Permission.sms.request();
    if (!status.isGranted) {
      throw Exception('SMS permission denied');
    }

    try {
      final List<dynamic> messages = await platform
          .invokeMethod('getSmsMessages', {'address': 'M-Money'});
      
      developer.log('Received ${messages.length} messages');

      // Filter M-Money transaction messages
      final filteredMessages = messages
          .where((message) =>
              message['body'] != null &&
              message['address'] == 'M-Money' &&
              (message['body'].toString().contains('transferred to') ||
               message['body'].toString().contains('payment of') ||
               message['body'].toString().contains('received')))
          .toList();

      developer.log('Filtered ${filteredMessages.length} M-Money transaction messages');

      final transactions = filteredMessages
          .map((message) {
            try {
              developer.log('Processing transaction: ${message['body']}');
              return Transaction.fromSms(
                message['body'] as String,
                messageDate:
                    DateTime.fromMillisecondsSinceEpoch(message['date'] as int),
              );
            } catch (e) {
              developer.log('Error processing message: $e');
              return null;
            }
          })
          .whereType<Transaction>()
          .toList();

      developer.log('Parsed ${transactions.length} transactions');

      // Sort transactions by date
      transactions.sort((a, b) => b.date.compareTo(a.date));

      return transactions;
    } catch (e) {
      developer.log('Error reading SMS: $e', error: e);
      throw Exception('Failed to read SMS: $e');
    }
  }
}
