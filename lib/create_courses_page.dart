import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateCoursesPage extends StatefulWidget {
  const CreateCoursesPage({Key? key}) : super(key: key);

  @override
  _CreateCoursesPageState createState() => _CreateCoursesPageState();
}

class _CreateCoursesPageState extends State<CreateCoursesPage> {
  final TextEditingController _courseNameController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  String _selectedSession = 'Day';
  String? _selectedInstructorId;
  List<Map<String, dynamic>> _instructors = [];

  @override
  void initState() {
    super.initState();
    _loadInstructors();
  }

  Future<void> _loadInstructors() async {
    try {
      final querySnapshot = await _firestore.collection('instructors').get();
      setState(() {
        _instructors = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? 'Unnamed Instructor',
          };
        }).toList();
        if (_instructors.isNotEmpty) {
          _selectedInstructorId = _instructors[0]['id'];
        }
      });
    } catch (e) {
      // Handle error if needed
    }
  }

  Future<void> _addCourse() async {
    final courseName = _courseNameController.text.trim();
    if (courseName.isEmpty || _selectedInstructorId == null) return;

    try {
      await _firestore.collection('instructor_courses').add({
        'instructorId': _selectedInstructorId,
        'courseName': courseName,
        'session': _selectedSession,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _courseNameController.clear();
      setState(() {
        _selectedSession = 'Day';
        if (_instructors.isNotEmpty) {
          _selectedInstructorId = _instructors[0]['id'];
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Course "$courseName" added successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add course: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Course'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _courseNameController,
              decoration: InputDecoration(
                labelText: 'Course Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedSession,
              decoration: InputDecoration(
                labelText: 'Session',
                border: OutlineInputBorder(),
              ),
              items: ['Day', 'Evening', 'Weekend']
                  .map((session) => DropdownMenuItem(
                        value: session,
                        child: Text(session),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSession = value ?? 'Day';
                });
              },
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedInstructorId,
              decoration: InputDecoration(
                labelText: 'Instructor',
                border: OutlineInputBorder(),
              ),
              items: _instructors.map((instructor) {
                return DropdownMenuItem<String>(
                  value: instructor['id'],
                  child: Text(instructor['name']),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedInstructorId = value;
                });
              },
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: _addCourse,
              child: Text('Add Course'),
            ),
          ],
        ),
      ),
    );
  }
}
