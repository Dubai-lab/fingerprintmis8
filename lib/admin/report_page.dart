import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';

class AdminReportPage extends StatefulWidget {
  final String courseId;
  final String courseName;
  final String courseCode;
  final String instructorName;
  final String reportType;
  final String startDate;
  final String endDate;

  const AdminReportPage({
    Key? key,
    required this.courseId,
    required this.courseName,
    required this.courseCode,
    required this.instructorName,
    required this.reportType,
    required this.startDate,
    required this.endDate,
  }) : super(key: key);

  @override
  _AdminReportPageState createState() => _AdminReportPageState();
}

class _AdminReportPageState extends State<AdminReportPage> {
  List<Map<String, dynamic>> _attendanceReports = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadAttendanceReports();
  }

  Future<void> _loadAttendanceReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      DateTime? startDate;
      if (widget.startDate.isNotEmpty) {
        startDate = DateTime.parse(widget.startDate);
      }

      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('instructor_courses')
          .doc(widget.courseId)
          .collection('attendance');

      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: startDate);
      }

      final attendanceSnapshot = await query.get();

      _attendanceReports = attendanceSnapshot.docs.map((doc) {
        final data = doc.data();
        String studentName = data['studentName'] ?? 'Unknown';

        // If studentName is unknown, try to fetch from students collection using regNumber
        if (studentName == 'Unknown' && data.containsKey('regNumber')) {
          final regNumber = data['regNumber'];
          // For now set as Unknown, you can implement async fetch here if needed
          studentName = 'Unknown';
        }

        return {
          'id': doc.id,
          'studentName': studentName,
          'regNumber': data['regNumber'] ?? '',
          'timestamp': data['timestamp']?.toDate() ?? DateTime.now(),
          'status': data['status'] ?? 'Present',
          'type': data['type'] ?? widget.reportType,
          'courseName': widget.courseName,
        };
      }).toList();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading attendance reports: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _exportToCSV() async {
    if (_attendanceReports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attendance records to export')),
      );
      return;
    }

    try {
      // Request storage permission
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission is required to download files')),
        );
        return;
      }

      List<List<String>> csvData = [
        ['RegNumber', 'Student Name', 'Date', 'Status', 'Type', 'Course'],
        ..._attendanceReports.map((record) => [
              record['regNumber'],
              record['studentName'],
              record['timestamp'] != null
                  ? DateFormat('yyyy-MM-dd HH:mm').format(record['timestamp'])
                  : '',
              record['status'],
              record['type'],
              record['courseName'] ?? '',
            ]),
      ];

      String csv = const ListToCsvConverter().convert(csvData);

      // Save to Downloads directory
      final directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${widget.courseCode}_${widget.reportType}_report_$timestamp.csv';
      final path = '${directory.path}/$fileName';
      final file = File(path);

      await file.writeAsString(csv);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV downloaded to Downloads folder')),
      );

      // Open the file using the default app
      await OpenFile.open(path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading CSV: $e')),
      );
    }
  }

  Future<void> _printReport() async {
    if (_attendanceReports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attendance records to print')),
      );
      return;
    }

    try {
      // Generate CSV data
      List<List<String>> csvData = [
        ['RegNumber', 'Student Name', 'Date', 'Status', 'Type', 'Course'],
        ..._attendanceReports.map((record) => [
              record['regNumber'],
              record['studentName'],
              record['timestamp'] != null
                  ? DateFormat('yyyy-MM-dd HH:mm').format(record['timestamp'])
                  : '',
              record['status'],
              record['type'],
              record['courseName'] ?? '',
            ]),
      ];

      String csv = const ListToCsvConverter().convert(csvData);

      // Create a formatted report with header
      String reportContent = '''
ATTENDANCE REPORT
================

Course Information:
- Course Name: ${widget.courseName}
- Course Code: ${widget.courseCode}
- Instructor: ${widget.instructorName}
- Report Type: ${widget.reportType}
- Total Records: ${_attendanceReports.length}

Report Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}

$csv

================
End of Report
''';

      // Show options dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Print/Export Options - ${widget.courseName}'),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.print),
                  title: const Text('Print Report'),
                  subtitle: const Text('Print directly to printer'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _printDocument(reportContent);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.share),
                  title: const Text('Share Report'),
                  subtitle: const Text('Share via email, WhatsApp, etc.'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _shareReport(reportContent);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.preview),
                  title: const Text('Preview Only'),
                  subtitle: const Text('View report content'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _showPreview(reportContent);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error preparing report: $e')),
      );
    }
  }

  Future<void> _printDocument(String content) async {
    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          final pdf = await Printing.convertHtml(
            format: format,
            html: '''
            <html>
              <head>
                <style>
                  body { font-family: Arial, sans-serif; margin: 20px; }
                  h1 { color: #333; border-bottom: 2px solid #333; padding-bottom: 10px; }
                  h2 { color: #666; margin-top: 30px; }
                  table { width: 100%; border-collapse: collapse; margin-top: 20px; }
                  th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
                  th { background-color: #f2f2f2; font-weight: bold; }
                  .header-info { background-color: #f9f9f9; padding: 15px; margin-bottom: 20px; border-radius: 5px; }
                </style>
              </head>
              <body>
                <h1>Attendance Report</h1>
                <div class="header-info">
                  <p><strong>Course Name:</strong> ${widget.courseName}</p>
                  <p><strong>Course Code:</strong> ${widget.courseCode}</p>
                  <p><strong>Instructor:</strong> ${widget.instructorName}</p>
                  <p><strong>Report Type:</strong> ${widget.reportType}</p>
                  <p><strong>Total Records:</strong> ${_attendanceReports.length}</p>
                  <p><strong>Generated:</strong> ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}</p>
                </div>
                <table>
                  <tr>
                    <th>RegNumber</th>
                    <th>Student Name</th>
                    <th>Date</th>
                    <th>Status</th>
                    <th>Type</th>
                    <th>Course</th>
                  </tr>
                  ${_attendanceReports.map((record) => '''
                  <tr>
                    <td>${record['regNumber']}</td>
                    <td>${record['studentName']}</td>
                    <td>${record['timestamp'] != null ? DateFormat('yyyy-MM-dd HH:mm').format(record['timestamp']) : ''}</td>
                    <td>${record['status']}</td>
                    <td>${record['type']}</td>
                    <td>${record['courseName'] ?? ''}</td>
                  </tr>
                  ''').join('')}
                </table>
              </body>
            </html>
            ''',
          );
          return pdf;
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error printing: $e')),
      );
    }
  }

  Future<void> _shareReport(String content) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${widget.courseCode}_${widget.reportType}_report_$timestamp.txt';
      final path = '${directory.path}/$fileName';
      final file = File(path);

      await file.writeAsString(content);

      await Share.shareXFiles(
        [XFile(path)],
        text: 'Attendance Report - ${widget.courseName} (${widget.courseCode})',
        subject: 'Attendance Report',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing report: $e')),
      );
    }
  }

  Future<void> _showPreview(String content) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Report Preview - ${widget.courseName}'),
        content: Container(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(content),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceTable() {
    if (_attendanceReports.isEmpty) {
      return const Center(child: Text('No attendance records found.'));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('RegNumber')),
          DataColumn(label: Text('Student Name')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Activity')),
          DataColumn(label: Text('Course')),
        ],
        rows: _attendanceReports.map((record) {
          final timestamp = record['timestamp'] as DateTime?;
          final formattedDate = timestamp != null
              ? '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}'
              : 'Unknown';
          return DataRow(cells: [
            DataCell(Text(record['regNumber'])),
            DataCell(Text(record['studentName'])),
            DataCell(Text(formattedDate)),
            DataCell(Text(record['status'])),
            DataCell(Text(record['type'])),
            DataCell(Text(record['courseName'] ?? '')),
          ]);
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.courseName} - ${widget.reportType} Report'),
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download CSV',
            onPressed: _exportToCSV,
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print Report',
            onPressed: _printReport,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAttendanceReports,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Course Information
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Course Information',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text('Course Name: ${widget.courseName}'),
                              Text('Course Code: ${widget.courseCode}'),
                              Text('Instructor: ${widget.instructorName}'),
                              Text('Report Type: ${widget.reportType}'),
                              if (widget.startDate.isNotEmpty)
                                Text('Start Date: ${widget.startDate}'),
                              if (widget.endDate.isNotEmpty)
                                Text('End Date: ${widget.endDate}'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Summary Information
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Records: ${_attendanceReports.length}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.download),
                                    onPressed: _exportToCSV,
                                    tooltip: 'Download CSV',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.print),
                                    onPressed: _printReport,
                                    tooltip: 'Print Report',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Attendance Table
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Attendance Records',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 16),
                                Expanded(child: _buildAttendanceTable()),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
