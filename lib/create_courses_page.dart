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

  DateTime? _startDate;
  DateTime? _endDate;

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
    if (courseName.isEmpty || _selectedInstructorId == null || _startDate == null || _endDate == null) return;

    try {
      // Find instructor name from _instructors list
      final instructor = _instructors.firstWhere(
        (inst) => inst['id'] == _selectedInstructorId,
        orElse: () => {'name': 'Unknown'},
      );
      final instructorName = instructor['name'] ?? 'Unknown';

      await _firestore.collection('instructor_courses').add({
        'instructorId': _selectedInstructorId,
        'instructorName': instructorName,
        'courseName': courseName,
        'session': _selectedSession,
        'startDate': _startDate,
        'endDate': _endDate,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _courseNameController.clear();
      setState(() {
        _selectedSession = 'Day';
        _startDate = null;
        _endDate = null;
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
        backgroundColor: Colors.deepPurple.shade600,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade200, Colors.deepPurple.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: EdgeInsets.all(16),
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              color: Colors.white.withOpacity(0.9),
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Create Course',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    SizedBox(height: 20),
                    TextField(
                      controller: _courseNameController,
                      decoration: InputDecoration(
                        labelText: 'Course Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.book, color: Colors.deepPurple),
                      ),
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedSession,
                      decoration: InputDecoration(
                        labelText: 'Session',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedInstructorId,
                      decoration: InputDecoration(
                        labelText: 'Instructor',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InputDatePickerFormField(
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            fieldLabelText: 'Start Date',
                            initialDate: _startDate ?? DateTime.now(),
                            onDateSubmitted: (date) {
                              setState(() {
                                _startDate = date;
                              });
                            },
                            onDateSaved: (date) {
                              setState(() {
                                _startDate = date;
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: InputDatePickerFormField(
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            fieldLabelText: 'End Date',
                            initialDate: _endDate ?? DateTime.now(),
                            onDateSubmitted: (date) {
                              setState(() {
                                _endDate = date;
                              });
                            },
                            onDateSaved: (date) {
                              setState(() {
                                _endDate = date;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _addCourse,
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 50),
                        backgroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('Add Course', style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
