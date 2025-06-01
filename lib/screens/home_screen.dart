import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/sms_service.dart';
import 'package:intl/intl.dart';
import 'charts_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final _smsService = SmsService();
  List<Transaction> _transactions = [];
  List<Transaction> _filteredTransactions = [];
  bool _isLoading = true;
  String? _error;
  DateTimeRange? _selectedDateRange;
  late TabController _tabController;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTransactions();
    // Check system theme preference
    _checkSystemTheme();
  }

  Future<void> _checkSystemTheme() async {
    final brightness = MediaQuery.of(context).platformBrightness;
    setState(() {
      _isDarkMode = brightness == Brightness.dark;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final transactions = await _smsService.getTransactions();
      setState(() {
        _transactions = transactions;
        _filterTransactions();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterTransactions() {
    if (_selectedDateRange == null) {
      _filteredTransactions = List.from(_transactions);
      return;
    }

    _filteredTransactions = _transactions.where((transaction) {
      return transaction.date.isAfter(_selectedDateRange!.start) &&
          transaction.date
              .isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
    }).toList();
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _filterTransactions();
      });
    }
  }

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeData = _isDarkMode ? _darkTheme : _lightTheme;
    
    return MaterialApp(
      theme: themeData,
      home: Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: const Text('MoMo Transactions', 
            style: TextStyle(
              color: Color.fromARGB(255, 254, 253, 253),
              fontSize: 20,
              fontWeight: FontWeight.bold
            )
          ),
          leading: Container(
            padding: const EdgeInsets.all(10.0),
            child: const Image(
              image: AssetImage('assets/images/momoLogo.webp'),
            )
          ),
          backgroundColor: Colors.green,
          actions: [
            IconButton(
              icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode, 
                color: Colors.white),
              onPressed: _toggleTheme,
            ),
            IconButton(
              icon: const Icon(Icons.calendar_today, color: Colors.white),
              onPressed: _selectDateRange,
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadTransactions,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.list), text: 'Transactions'),
              Tab(icon: Icon(Icons.bar_chart), text: 'Analytics'),
            ],
            labelColor: Colors.white,
            indicatorColor: const Color.fromARGB(255, 255, 254, 254),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            Container(
              color: themeData.scaffoldBackgroundColor,
              child: _buildTransactionList(themeData),
            ),
            ChartScreen(transactions: _filteredTransactions),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList(ThemeData theme) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading transactions...',
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color?.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error: $_error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTransactions,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredTransactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No transactions found',
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
            ),
            if (_selectedDateRange != null)
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedDateRange = null;
                    _filterTransactions();
                  });
                },
                child: const Text('Clear date filter'),
              ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_selectedDateRange != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: theme.cardColor,
              child: ListTile(
                leading: Icon(Icons.date_range, color: theme.primaryColor),
                title: Text(
                  '${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.start)} - '
                  '${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.end)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.close, color: theme.iconTheme.color),
                  onPressed: () {
                    setState(() {
                      _selectedDateRange = null;
                      _filterTransactions();
                    });
                  },
                ),
              ),
            ),
          ),
        _buildTransactionSummary(theme),
        Expanded(
          child: RefreshIndicator(
            color: Colors.green,
            onRefresh: _loadTransactions,
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _filteredTransactions.length,
              itemBuilder: (context, index) {
                final transaction = _filteredTransactions[index];
                return _buildTransactionCard(transaction, theme);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionSummary(ThemeData theme) {
    double totalIncoming = 0;
    double totalOutgoing = 0;
    double totalPayments = 0;

    for (var transaction in _filteredTransactions) {
      if (transaction.isIncoming) {
        totalIncoming += transaction.amount;
      } else {
        if (transaction.description.toLowerCase().contains('payment of')) {
          totalPayments += transaction.amount;
        } else {
          totalOutgoing += transaction.amount;
        }
      }
    }

    final formatter = NumberFormat("#,##0", "en_US");

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSummaryItem('Income', totalIncoming, Colors.green, Icons.arrow_downward, theme),
            Container(height: 40, width: 1, color: theme.dividerColor),
            _buildSummaryItem('Expenses', totalOutgoing, Colors.red, Icons.arrow_upward, theme),
            Container(height: 40, width: 1, color: theme.dividerColor),
            _buildSummaryItem('Payments', totalPayments, Colors.orange, Icons.payment, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, double amount, Color color, IconData icon, ThemeData theme) {
    final formatter = NumberFormat("#,##0", "en_US");
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 14, 
            color: theme.textTheme.bodyLarge?.color?.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${formatter.format(amount)} RWF',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionCard(Transaction transaction, ThemeData theme) {
    final formatter = NumberFormat("#,##0", "en_US");
    final bool isPayment = transaction.description.toLowerCase().contains('payment of');
    final amountColor = transaction.isIncoming 
        ? Colors.green 
        : (isPayment ? Colors.orange : Colors.red);
    final amountPrefix = transaction.isIncoming ? "+" : "-";
    final IconData transactionIcon = isPayment 
        ? Icons.payment 
        : (transaction.isIncoming ? Icons.arrow_downward : Icons.arrow_upward);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: amountColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(transactionIcon, color: amountColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        DateFormat('MMM dd, HH:mm').format(transaction.date),
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color?.withOpacity(0.6),
                          fontSize: 13,
                        ),
                      ),
                      if (transaction.reference != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.dividerColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Ref: ${transaction.reference}',
                            style: TextStyle(
                              color: theme.textTheme.bodyLarge?.color?.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '$amountPrefix${formatter.format(transaction.amount)} RWF',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Light theme
  final ThemeData _lightTheme = ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.green,
    scaffoldBackgroundColor: Colors.grey[100],
    cardColor: Colors.white,
    appBarTheme: const AppBarTheme(
      color: Colors.green,
      iconTheme: IconThemeData(color: Colors.white),
    ),
    tabBarTheme: const TabBarTheme(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      indicatorColor: Colors.white,
    ),
    dividerColor: Colors.grey[300],
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black87),
    ),
  );

  // Dark theme
  final ThemeData _darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.green,
    scaffoldBackgroundColor: const Color(0xFF121212),
    cardColor: const Color(0xFF1E1E1E),
    appBarTheme: const AppBarTheme(
      color: Colors.green,
      iconTheme: IconThemeData(color: Colors.white),
    ),
    tabBarTheme: const TabBarTheme(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      indicatorColor: Colors.white,
    ),
    dividerColor: Colors.grey[700],
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
    ),
    iconTheme: const IconThemeData(color: Colors.white),
  );
}