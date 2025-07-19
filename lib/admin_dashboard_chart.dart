import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminDashboardChart extends StatelessWidget {
  final int studentCount;
  final int instructorCount;
  final int invigilatorCount;
  final int securityCount;

  const AdminDashboardChart({
    Key? key,
    required this.studentCount,
    required this.instructorCount,
    required this.invigilatorCount,
    required this.securityCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double aspectRatio = constraints.maxWidth < 400 ? 1.0 : 1.7;
        return AspectRatio(
          aspectRatio: aspectRatio,
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _getMaxY(),
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: _bottomTitles,
                        reservedSize: 32,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: _buildBarGroups(),
                  gridData: FlGridData(show: true),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double _getMaxY() {
    final maxCount = [studentCount, instructorCount, invigilatorCount, securityCount].reduce((a, b) => a > b ? a : b);
    return (maxCount * 1.2).ceilToDouble();
  }

  List<BarChartGroupData> _buildBarGroups() {
    return [
      BarChartGroupData(
        x: 0,
        barRods: [
          BarChartRodData(
            toY: studentCount.toDouble(),
            color: Colors.blue,
            width: 22,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      ),
      BarChartGroupData(
        x: 1,
        barRods: [
          BarChartRodData(
            toY: instructorCount.toDouble(),
            color: Colors.green,
            width: 22,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      ),
      BarChartGroupData(
        x: 2,
        barRods: [
          BarChartRodData(
            toY: invigilatorCount.toDouble(),
            color: Colors.orange,
            width: 22,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      ),
      BarChartGroupData(
        x: 3,
        barRods: [
          BarChartRodData(
            toY: securityCount.toDouble(),
            color: Colors.red,
            width: 22,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      ),
    ];
  }

  Widget _bottomTitles(double value, TitleMeta meta) {
    const style = TextStyle(
      color: Colors.black87,
      fontWeight: FontWeight.bold,
      fontSize: 14,
    );
    String text;
    switch (value.toInt()) {
      case 0:
        text = 'Students';
        break;
      case 1:
        text = 'Instructors';
        break;
      case 2:
        text = 'Invigilators';
        break;
      case 3:
        text = 'Security';
        break;
      default:
        text = '';
        break;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(text, style: style),
    );
  }
}
