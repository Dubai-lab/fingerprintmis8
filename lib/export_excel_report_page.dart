import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

class ExportExcelReportPage extends StatefulWidget {
  const ExportExcelReportPage({Key? key}) : super(key: key);

  @override
  _ExportExcelReportPageState createState() => _ExportExcelReportPageState();
}

class _ExportExcelReportPageState extends State<ExportExcelReportPage> {
  bool _isExporting = false;

  Future<void> _exportAttendanceToExcel() async {
    setState(() {
      _isExporting = true;
    });

    try {
      // Fetch attendance data from Firestore
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('attendance_records')
          .orderBy('timestamp')
          .get();

      // Create CSV content
      StringBuffer csvContent = StringBuffer();
      csvContent.writeln('Student ID,Student Name,Instructor ID,Timestamp,Status');

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        String timestamp = '';
        if (data['timestamp'] != null) {
          timestamp = (data['timestamp'] as Timestamp).toDate().toIso8601String();
        }
        csvContent.writeln(
            '${data['studentId'] ?? ''},${data['studentName'] ?? ''},${data['instructorId'] ?? ''},$timestamp,${data['status'] ?? ''}');
      }

      // Save CSV file to device
      final directory = Directory.systemTemp;
      final file = File('${directory.path}/attendance_report_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvContent.toString());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV report saved to ${file.path}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export report: $e')),
      );
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Export Excel Reports'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: _isExporting ? null : _exportAttendanceToExcel,
          child: _isExporting
              ? CircularProgressIndicator(color: Colors.white)
              : Text('Export Attendance Report to CSV'),
        ),
      ),
    );
  }
}
