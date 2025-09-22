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
  final String? courseId;
  final String? courseName;
  final String? courseCode;
  final String? instructorName;
  final String? reportType;

  const AdminReportPage({
    Key? key,
    this.courseId,
    this.courseName,
    this.courseCode,
    this.instructorName,
    this.reportType,
  }) : super(key: key);

  @override
  _AdminReportPageState createState() => _AdminReportPageState();
}

class _AdminReportPageState extends State<AdminReportPage> {
  List<Map<String, dynamic>> _attendanceRecords = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _noRecordMessage = '';

  @override
  void initState() {
    super.initState();
    _loadAttendanceRecords();
  }

  Future<void> _loadAttendanceRecords() async {
    if (widget.courseId == null || widget.courseId!.isEmpty || widget.reportType == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Course ID or report type not provided';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _noRecordMessage = '';
      _attendanceRecords = [];
    });

    try {
      // Load attendance from the invigilator_activities collection
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('invigilator_activities')
          .doc(widget.reportType)
          .collection('attendance')
          .where('courseId', isEqualTo: widget.courseId);

      final querySnapshot = await query.orderBy('timestamp', descending: true).get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _noRecordMessage = 'No attendance records found for ${widget.reportType} in this course.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _attendanceRecords = querySnapshot.docs.map((doc) {
          final data = doc.data();

          return {
            'id': doc.id,
            'regNumber': data['regNumber'] ?? '',
            'timestamp': data['timestamp']?.toDate() ?? DateTime.now(),
            'status': data['status'] ?? 'Present',
            'activity': data['activity'] ?? widget.reportType ?? 'Unknown',
            'courseId': data['courseId'] ?? '',
            'courseName': widget.courseName ?? '',
            'courseCode': widget.courseCode ?? '',
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading attendance records: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _exportToCSV() async {
    if (_attendanceRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attendance records to export')),
      );
      return;
    }

    try {
      // Request storage permissions first
      var storageStatus = await Permission.storage.request();

      // For Android 11+ (API 30+), we need MANAGE_EXTERNAL_STORAGE for Downloads folder
      bool needsManageStorage = false;
      if (await Permission.manageExternalStorage.isGranted == false) {
        needsManageStorage = true;
        var manageStorageStatus = await Permission.manageExternalStorage.request();
        if (!manageStorageStatus.isGranted) {
          // If MANAGE_EXTERNAL_STORAGE is denied, try alternative approach
          _showStoragePermissionExplanation();
          return;
        }
      }

      List<List<String>> csvData = [
        ['RegNumber', 'Date', 'Status', 'Type', 'Course'],
        ..._attendanceRecords.map((record) => [
              record['regNumber'],
              record['timestamp'] != null
                  ? DateFormat('yyyy-MM-dd HH:mm').format(record['timestamp'])
                  : '',
              record['status'],
              record['activity'],
              record['courseName'] ?? '',
            ]),
      ];

      String csv = const ListToCsvConverter().convert(csvData);

      // Try to save to Downloads directory first
      try {
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
          SnackBar(content: Text('CSV downloaded to Downloads folder: $fileName')),
        );

        // Open the file using the default app
        await OpenFile.open(path);
      } catch (e) {
        // If Downloads folder fails, try app-specific directory
        await _saveToAppDirectory(csv);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading CSV: $e')),
      );
    }
  }

  Future<void> _saveToAppDirectory(String csv) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${widget.courseCode}_${widget.reportType}_report_$timestamp.csv';
      final path = '${directory.path}/$fileName';
      final file = File(path);

      await file.writeAsString(csv);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV saved to app documents: $fileName\nYou can find it in your device file manager'),
          duration: Duration(seconds: 5),
        ),
      );

      // Open the file using the default app
      await OpenFile.open(path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving file: $e')),
      );
    }
  }

  void _showStoragePermissionExplanation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Storage Permission Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('To download reports to your Downloads folder, this app needs storage access permission.'),
            SizedBox(height: 16),
            Text('Why we need this permission:'),
            SizedBox(height: 8),
            Text('• Save attendance reports as CSV files'),
            Text('• Allow you to access reports from your Downloads folder'),
            Text('• Share reports with other apps'),
            SizedBox(height: 16),
            Text('You can still view and share reports without this permission, but files will be saved in the app\'s private folder.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Try alternative save method
              List<List<String>> csvData = [
                ['RegNumber', 'Date', 'Status', 'Type', 'Course'],
                ..._attendanceRecords.map((record) => [
                      record['regNumber'],
                      record['timestamp'] != null
                          ? DateFormat('yyyy-MM-dd HH:mm').format(record['timestamp'])
                          : '',
                      record['status'],
                      record['activity'],
                      record['courseName'] ?? '',
                    ]),
              ];
              String csv = const ListToCsvConverter().convert(csvData);
              await _saveToAppDirectory(csv);
            },
            child: Text('Continue Anyway'),
          ),
        ],
      ),
    );
  }

  Future<void> _printReport() async {
    if (_attendanceRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attendance records to print')),
      );
      return;
    }

    try {
      // Generate CSV data
      List<List<String>> csvData = [
        ['RegNumber', 'Date', 'Status', 'Type', 'Course'],
        ..._attendanceRecords.map((record) => [
              record['regNumber'],
              record['timestamp'] != null
                  ? DateFormat('yyyy-MM-dd HH:mm').format(record['timestamp'])
                  : '',
              record['status'],
              record['activity'],
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
- Total Records: ${_attendanceRecords.length}

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
                  <p><strong>Total Records:</strong> ${_attendanceRecords.length}</p>
                  <p><strong>Generated:</strong> ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}</p>
                </div>
                <table>
                  <tr>
                    <th>RegNumber</th>
                    <th>Date</th>
                    <th>Status</th>
                    <th>Type</th>
                    <th>Course</th>
                  </tr>
                  ${_attendanceRecords.map((record) => '''
                  <tr>
                    <td>${record['regNumber']}</td>
                    <td>${record['timestamp'] != null ? DateFormat('yyyy-MM-dd HH:mm').format(record['timestamp']) : ''}</td>
                    <td>${record['status']}</td>
                    <td>${record['activity']}</td>
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
    if (_attendanceRecords.isEmpty) {
      return const Center(child: Text('No attendance records found.'));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('RegNumber')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Activity')),
          DataColumn(label: Text('Course')),
        ],
        rows: _attendanceRecords.map((record) {
          final timestamp = record['timestamp'] as DateTime?;
          final formattedDate = timestamp != null
              ? '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}'
              : 'Unknown';
          return DataRow(cells: [
            DataCell(Text(record['regNumber'])),
            DataCell(Text(formattedDate)),
            DataCell(Text(record['status'])),
            DataCell(Text(record['activity'])),
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
                        onPressed: _loadAttendanceRecords,
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
                                'Total Records: ${_attendanceRecords.length}',
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
