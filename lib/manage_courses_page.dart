import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ManageCoursesPage extends StatefulWidget {
  const ManageCoursesPage({Key? key}) : super(key: key);

  @override
  _ManageCoursesPageState createState() => _ManageCoursesPageState();
}

class _ManageCoursesPageState extends State<ManageCoursesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _filteredCourses = [];
  String _filter = 'Active'; // Active or Ended

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    try {
      final querySnapshot = await _firestore.collection('instructor_courses').get();
      final now = DateTime.now();
      List<Map<String, dynamic>> courses = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      setState(() {
        _courses = courses;
        _applyFilter();
      });
    } catch (e) {
      // Handle error if needed
    }
  }

  void _applyFilter() {
    final now = DateTime.now();
    if (_filter == 'Active') {
      _filteredCourses = _courses.where((course) {
        final endDate = (course['endDate'] as Timestamp?)?.toDate();
        return endDate == null || endDate.isAfter(now);
      }).toList();
    } else {
      _filteredCourses = _courses.where((course) {
        final endDate = (course['endDate'] as Timestamp?)?.toDate();
        return endDate != null && endDate.isBefore(now);
      }).toList();
    }
  }

  void _setFilter(String filter) {
    setState(() {
      _filter = filter;
      _applyFilter();
    });
  }

  void _viewCourseDetails(Map<String, dynamic> course) {
    showDialog(
      context: context,
      builder: (context) {
        final startDate = (course['startDate'] as Timestamp?)?.toDate();
        final endDate = (course['endDate'] as Timestamp?)?.toDate();
        final registrationDeadline = (course['registrationDeadline'] as Timestamp?)?.toDate();
        final registrationPeriodDays = course['registrationPeriodDays'] ?? 'Not Set';
        final credits = course['creditHours'] ?? 0;
        final totalDays = course['totalDays'] ?? 0;
        return AlertDialog(
          title: Text('Course Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Course Name: ${course['courseName'] ?? ''}'),
              SizedBox(height: 8),
              Text('Session: ${course['session'] ?? ''}'),
              SizedBox(height: 8),
              Text('Credits: $credits'),
              SizedBox(height: 8),
              Text('Total Days: $totalDays'),
              SizedBox(height: 8),
              Text('Instructor: ${course['instructorName'] ?? course['instructorId'] ?? ''}'),
              SizedBox(height: 8),
              Text('Start Date: ${startDate != null ? startDate.toLocal().toString().split(" ")[0] : 'N/A'}'),
              SizedBox(height: 8),
              Text('End Date: ${endDate != null ? endDate.toLocal().toString().split(" ")[0] : 'N/A'}'),
              SizedBox(height: 8),
              Divider(),
              SizedBox(height: 8),
              Text('Registration Period: $registrationPeriodDays days', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
              SizedBox(height: 8),
              Text('Registration Deadline: ${registrationDeadline != null ? registrationDeadline.toLocal().toString().split(" ")[0] : 'Not Set'}'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Close')),
          ],
        );
      },
    );
  }

  void _editCourse(Map<String, dynamic> course) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditCoursePage(course: course, onSave: _loadCourses),
      ),
    );
  }

  void _deleteCourse(String courseId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Course'),
        content: Text('Are you sure you want to delete this course?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await _firestore.collection('instructor_courses').doc(courseId).delete();
      _loadCourses();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Courses'),
        backgroundColor: Colors.deepPurple,
        actions: [
          PopupMenuButton<String>(
            onSelected: _setFilter,
            itemBuilder: (context) => [
              PopupMenuItem(value: 'Active', child: Text('Active Courses')),
              PopupMenuItem(value: 'Ended', child: Text('Ended Courses')),
            ],
            icon: Icon(Icons.filter_list),
          ),
        ],
      ),
      body: _filteredCourses.isEmpty
          ? Center(child: Text('No courses found.'))
          : ListView.builder(
              itemCount: _filteredCourses.length,
              itemBuilder: (context, index) {
                final course = _filteredCourses[index];
                final credits = course['creditHours'] ?? 0;
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(course['courseName'] ?? ''),
                    subtitle: Text('Session: ${course['session'] ?? ''} | Credits: $credits'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'view') {
                          _viewCourseDetails(course);
                        } else if (value == 'edit') {
                          _editCourse(course);
                        } else if (value == 'delete') {
                          _deleteCourse(course['id']);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(value: 'view', child: Text('View Details')),
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class EditCoursePage extends StatefulWidget {
  final Map<String, dynamic> course;
  final VoidCallback onSave;

  const EditCoursePage({Key? key, required this.course, required this.onSave}) : super(key: key);

  @override
  _EditCoursePageState createState() => _EditCoursePageState();
}

class _EditCoursePageState extends State<EditCoursePage> {
  late TextEditingController _courseNameController;
  late String _selectedSession;
  late int _selectedCredits;
  late int _selectedRegistrationPeriodDays;
  String? _selectedInstructorId;
  List<Map<String, dynamic>> _instructors = [];
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _registrationDeadline;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _courseNameController = TextEditingController(text: widget.course['courseName'] ?? '');
    _selectedSession = widget.course['session'] ?? 'Day';
    _selectedCredits = widget.course['creditHours'] ?? 10;
    _selectedRegistrationPeriodDays = widget.course['registrationPeriodDays'] ?? 3;
    _startDate = (widget.course['startDate'] as Timestamp?)?.toDate();
    _endDate = (widget.course['endDate'] as Timestamp?)?.toDate();
    _registrationDeadline = (widget.course['registrationDeadline'] as Timestamp?)?.toDate();
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
        if (_instructors.isNotEmpty && !_instructors.any((inst) => inst['id'] == _selectedInstructorId)) {
          _selectedInstructorId = _instructors[0]['id'];
        }
      });
    } catch (e) {
      // Handle error if needed
    }
  }

  Future<void> _saveCourse() async {
    final courseName = _courseNameController.text.trim();
    if (courseName.isEmpty || _selectedInstructorId == null || _startDate == null || _endDate == null) return;

    try {
      // Calculate totalDays based on creditHours
      final totalDays = _selectedCredits;
      
      // Calculate registration deadline if not already set
      final registrationDeadline = _registrationDeadline ?? _startDate!.subtract(Duration(days: 1));
      
      await _firestore.collection('instructor_courses').doc(widget.course['id']).update({
        'courseName': courseName,
        'session': _selectedSession,
        'creditHours': _selectedCredits,
        'totalDays': totalDays,
        'instructorId': _selectedInstructorId,
        'startDate': _startDate,
        'endDate': _endDate,
        'registrationDeadline': registrationDeadline,
        'registrationPeriodDays': _selectedRegistrationPeriodDays,
      });
      widget.onSave();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Course "$courseName" updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update course: $e')),
      );
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final initialDate = isStartDate ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now());
    final newDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (newDate != null) {
      setState(() {
        if (isStartDate) {
          _startDate = newDate;
        } else {
          _endDate = newDate;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Course'),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          color: Colors.white.withOpacity(0.9),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                TextField(
                  controller: _courseNameController,
                  decoration: InputDecoration(
                    labelText: 'Course Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.book, color: Colors.deepPurple),
                  ),
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedSession,
                  decoration: InputDecoration(
                    labelText: 'Session',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: ['Day', 'Evening', 'Weekend']
                      .map<DropdownMenuItem<String>>((session) => DropdownMenuItem<String>(value: session, child: Text(session)))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSession = value ?? 'Day';
                    });
                  },
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _selectedCredits,
                  decoration: InputDecoration(
                    labelText: 'Credit Hours',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.school, color: Colors.deepPurple),
                  ),
                  items: [10, 15, 20]
                      .map<DropdownMenuItem<int>>((credit) => DropdownMenuItem<int>(
                            value: credit,
                            child: Text('$credit Credits ($credit Days)'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCredits = value ?? 10;
                    });
                  },
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _selectedRegistrationPeriodDays,
                  decoration: InputDecoration(
                    labelText: 'Registration Period (days)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.schedule, color: Colors.deepPurple),
                  ),
                  items: [3, 7, 14, 21, 30]
                      .map<DropdownMenuItem<int>>((days) => DropdownMenuItem<int>(
                            value: days,
                            child: Text('$days days'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedRegistrationPeriodDays = value ?? 3;
                      // Recalculate deadline based on new period
                      if (_registrationDeadline != null && value != null) {
                        _registrationDeadline = DateTime.now().add(Duration(days: value));
                      }
                    });
                  },
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedInstructorId,
                  decoration: InputDecoration(
                    labelText: 'Instructor',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _instructors
                      .map((instructor) => DropdownMenuItem<String>(value: instructor['id'] as String, child: Text(instructor['name'])))
                      .toList(),
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
                      child: InkWell(
                        onTap: () => _selectDate(context, true),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Start Date',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(_startDate != null ? _startDate!.toLocal().toString().split(' ')[0] : ''),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context, false),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'End Date',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(_endDate != null ? _endDate!.toLocal().toString().split(' ')[0] : ''),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _saveCourse,
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                    backgroundColor: Colors.deepPurple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Save Changes', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
