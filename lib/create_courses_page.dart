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
  final TextEditingController _departmentController = TextEditingController();

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

  // Removed _loadDepartments method as departments are input as free text in _departmentController

  Future<void> _addCourse() async {
    final courseName = _courseNameController.text.trim();
    if (courseName.isEmpty || _selectedInstructorId == null || _startDate == null || _endDate == null || _departmentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

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
        'department': _departmentController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      _courseNameController.clear();
      setState(() {
        _selectedSession = 'Day';
        _startDate = null;
        _endDate = null;
        _departmentController.clear();
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
                    TextFormField(
                      controller: _departmentController,
                      decoration: InputDecoration(
                        labelText: 'Department',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.school, color: Colors.deepPurple),
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Enter department' : null,
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: _startDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() {
                                  _startDate = picked;
                                });
                              }
                            },
                            child: AbsorbPointer(
                              child: TextFormField(
                                decoration: InputDecoration(
                                  labelText: 'Start Date',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                controller: TextEditingController(
                                  text: _startDate == null ? '' : "${_startDate!.year}-${_startDate!.month.toString().padLeft(2,'0')}-${_startDate!.day.toString().padLeft(2,'0')}",
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: _endDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() {
                                  _endDate = picked;
                                });
                              }
                            },
                            child: AbsorbPointer(
                              child: TextFormField(
                                decoration: InputDecoration(
                                  labelText: 'End Date',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                controller: TextEditingController(
                                  text: _endDate == null ? '' : "${_endDate!.year}-${_endDate!.month.toString().padLeft(2,'0')}-${_endDate!.day.toString().padLeft(2,'0')}",
                                ),
                              ),
                            ),
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
