import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceSessionsPage extends StatefulWidget {
  final String courseId;
  final String courseName;

  const AttendanceSessionsPage({Key? key, required this.courseId, required this.courseName}) : super(key: key);

  @override
  _AttendanceSessionsPageState createState() => _AttendanceSessionsPageState();
}

class _AttendanceSessionsPageState extends State<AttendanceSessionsPage> {
  final TextEditingController _sessionNameController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _addSession() async {
    final sessionName = _sessionNameController.text.trim();
    if (sessionName.isEmpty) return;

    try {
      await _firestore.collection('attendance_sessions').add({
        'courseId': widget.courseId,
        'sessionName': sessionName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _sessionNameController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Session "$sessionName" added successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add session: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance Sessions for ${widget.courseName}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _sessionNameController,
              decoration: InputDecoration(
                labelText: 'Session Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: _addSession,
              child: Text('Add Session'),
            ),
            SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('attendance_sessions')
                    .where('courseId', isEqualTo: widget.courseId)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error loading sessions'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  final sessions = snapshot.data?.docs ?? [];
                  if (sessions.isEmpty) {
                    return Center(child: Text('No sessions added yet'));
                  }
                  return ListView.builder(
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final sessionName = session['sessionName'] ?? '';
                      return ListTile(
                        title: Text(sessionName),
                        // You can add onTap to navigate to attendance marking page for this session
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
