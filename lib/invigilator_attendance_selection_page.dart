import 'package:flutter/material.dart';

class InvigilatorAttendanceSelectionPage extends StatefulWidget {
  const InvigilatorAttendanceSelectionPage({Key? key}) : super(key: key);

  @override
  _InvigilatorAttendanceSelectionPageState createState() => _InvigilatorAttendanceSelectionPageState();
}

class _InvigilatorAttendanceSelectionPageState extends State<InvigilatorAttendanceSelectionPage> {
  String? _selectedAttendanceType;

  final List<String> _attendanceTypes = ['CAT', 'Exam', 'Conference'];

  void _proceed() {
    if (_selectedAttendanceType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select an attendance type')),
      );
      return;
    }
    // Navigate to attendance page with selected type as argument
    Navigator.pushNamed(context, '/attendance', arguments: {'type': _selectedAttendanceType});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Attendance Type'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Choose the type of attendance to take:', style: TextStyle(fontSize: 18)),
            SizedBox(height: 20),
            ..._attendanceTypes.map((type) => RadioListTile<String>(
              title: Text(type),
              value: type,
              groupValue: _selectedAttendanceType,
              onChanged: (value) {
                setState(() {
                  _selectedAttendanceType = value;
                });
              },
            )),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _proceed,
              child: Text('Proceed'),
            ),
          ],
        ),
      ),
    );
  }
}
