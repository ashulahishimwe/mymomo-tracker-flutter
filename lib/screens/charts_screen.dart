import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/transaction.dart';
import 'package:intl/intl.dart';

class ChartScreen extends StatefulWidget {
  final List<Transaction> transactions;

  const ChartScreen({super.key, required this.transactions});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  String _selectedPeriod = 'Monthly';
  final List<String> _periods = ['Weekly', 'Monthly', 'Yearly'];

  List<FlSpot> _getSpots() {
    if (widget.transactions.isEmpty) return [];
    
    final Map<DateTime, double> groupedData = {};
    DateTime? minDate;
    DateTime? maxDate;
    
    for (var transaction in widget.transactions) {
      final date = _getDateByPeriod(transaction.date);
      // Ensure we don't store negative values
      final amount = transaction.amount.abs();
      groupedData[date] = (groupedData[date] ?? 0) + 
          (transaction.isIncoming ? amount : -amount);
          
      minDate = minDate == null || date.isBefore(minDate) ? date : minDate;
      maxDate = maxDate == null || date.isAfter(maxDate) ? date : maxDate;
    }

    // Fill in missing dates with zero values
    if (minDate != null && maxDate != null) {
      DateTime current = minDate;
      while (current.isBefore(maxDate) || current.isAtSameMomentAs(maxDate)) {
        groupedData.putIfAbsent(current, () => 0);
        current = _getNextDate(current);
      }
    }

    final sortedDates = groupedData.keys.toList()..sort();
    return sortedDates.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        groupedData[entry.value]!.abs() // Ensure positive values
      );
    }).toList();
  }

  DateTime _getDateByPeriod(DateTime date) {
    switch (_selectedPeriod) {
      // case 'Daily':
      //   return DateTime(date.year, date.month, date.day);
      case 'Weekly':
        return DateTime(date.year, date.month, date.day - date.weekday);
      case 'Monthly':
        return DateTime(date.year, date.month);
      case 'Yearly':
        return DateTime(date.year);
      default:
        return date;
    }
  }

  DateTime _getNextDate(DateTime date) {
    switch (_selectedPeriod) {
      // case 'Daily':
      //   return date.add(const Duration(days: 1));
      case 'Weekly':
        return date.add(const Duration(days: 7));
      case 'Monthly':
        return DateTime(date.year, date.month + 1);
      case 'Yearly':
        return DateTime(date.year + 1);
      default:
        return date;
    }
  }

  @override
  Widget build(BuildContext context) {
    final spots = _getSpots();
    final formatter = NumberFormat("#,##0", "en_US");

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SegmentedButton<String>(
            segments: _periods.map((period) => 
              ButtonSegment<String>(
                value: period, 
                label: Text(period)
              )
            ).toList(),
            selected: {_selectedPeriod},
            onSelectionChanged: (Set<String> selection) {
              setState(() {
                _selectedPeriod = selection.first;
              });
            },
          ),
        ),
        if (spots.isEmpty)
          const Expanded(
            child: Center(
              child: Text('No data available for the selected period'),
            ),
          )
        else
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: 1000000, // Adjust based on your data range
                    verticalInterval: 1,
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const Text('0');
                          return Text(
                            '${formatter.format(value)} RWF',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                        interval: 1000000, // Adjust based on your data range
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value >= 0 && value < spots.length) {
                            final date = DateTime.fromMillisecondsSinceEpoch(
                              spots[value.toInt()].x.toInt()
                            );
                            return RotatedBox(
                              quarterTurns: 1,
                              child: Text(
                                _getFormattedDate(date),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                        interval: 1,
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Colors.green,
                            strokeWidth: 1,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.withOpacity(0.15),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      tooltipRoundedRadius: 8,
                      getTooltipItems: (List<LineBarSpot> touchedSpots) {
                        return touchedSpots.map((LineBarSpot touchedSpot) {
                          final value = touchedSpot.y.abs();
                          return LineTooltipItem(
                            '${formatter.format(value)} RWF',
                            const TextStyle(color: Colors.white, fontSize: 12),
                          );
                        }).toList();
                      },
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _getFormattedDate(DateTime date) {
    switch (_selectedPeriod) {
      // case 'Daily':
      //   return DateFormat('MMM d').format(date);
      case 'Weekly':
        return DateFormat('MMM d').format(date);
      case 'Monthly':
        return DateFormat('MMM y').format(date);
      case 'Yearly':
        return DateFormat('yyyy').format(date);
      default:
        return '';
    }
  }
}
