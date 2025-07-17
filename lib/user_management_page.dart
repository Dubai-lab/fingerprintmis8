import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({Key? key}) : super(key: key);

  @override
  _UserManagementPageState createState() => _UserManagementPageState();
}

enum UserType { all, students, instructors, invigilators, admins }

class _UserManagementPageState extends State<UserManagementPage> {
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _displayedUsers = [];
  bool _loading = true;
  UserType _selectedUserType = UserType.all;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchAllUsers();
  }

  Future<void> _fetchAllUsers() async {
    setState(() {
      _loading = true;
    });

    List<Map<String, dynamic>> users = [];

    try {
      // Fetch students
      final studentsSnapshot = await FirebaseFirestore.instance.collection('students').get();
      users.addAll(studentsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'regNumber': data['regNumber'] ?? '',
          'type': UserType.students,
        };
      }));

      // Fetch instructors
      final instructorsSnapshot = await FirebaseFirestore.instance.collection('instructors').get();
      users.addAll(instructorsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'type': UserType.instructors,
        };
      }));

      // Fetch invigilators
      final invigilatorsSnapshot = await FirebaseFirestore.instance.collection('invigilators').get();
      users.addAll(invigilatorsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'type': UserType.invigilators,
        };
      }));

      // Fetch admins
      final adminsSnapshot = await FirebaseFirestore.instance.collection('admins').get();
      users.addAll(adminsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'type': UserType.admins,
        };
      }));
    } catch (e) {
      print('Error fetching users: $e');
    }

    setState(() {
      _allUsers = users;
      _applyFilters();
      _loading = false;
    });
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = _allUsers;

    if (_selectedUserType != UserType.all) {
      filtered = filtered.where((user) => user['type'] == _selectedUserType).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((user) {
        final name = (user['name'] ?? '').toLowerCase();
        final regNumber = (user['regNumber'] ?? '').toLowerCase();
        return name.contains(query) || regNumber.contains(query);
      }).toList();
    }

    setState(() {
      _displayedUsers = filtered;
    });
  }

  Widget _buildUserList() {
    if (_loading) {
      return Center(child: CircularProgressIndicator());
    }
    if (_displayedUsers.isEmpty) {
      return Center(child: Text('No users found.'));
    }
    return ListView.builder(
      itemCount: _displayedUsers.length,
      itemBuilder: (context, index) {
        final user = _displayedUsers[index];
        return ListTile(
          title: Text(user['name'] ?? ''),
          subtitle: user['regNumber'] != null && user['regNumber'].isNotEmpty ? Text('Reg#: ${user['regNumber']}') : null,
          leading: Icon(Icons.person),
          onTap: () {
            // Optionally handle user tap
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple.shade600,
        elevation: 0,
        title: Text(
          'User Management',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
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
        child: Column(
          children: [
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              color: Colors.white.withOpacity(0.9),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Search by name or registration number',
                        prefixIcon: Icon(Icons.search, color: Colors.deepPurple),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        _searchQuery = value;
                        _applyFilters();
                      },
                    ),
                    SizedBox(height: 12),
                    DropdownButton<UserType>(
                      value: _selectedUserType,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: UserType.all, child: Text('All Users')),
                        DropdownMenuItem(value: UserType.students, child: Text('Students')),
                        DropdownMenuItem(value: UserType.instructors, child: Text('Instructors')),
                        DropdownMenuItem(value: UserType.invigilators, child: Text('Invigilators')),
                        DropdownMenuItem(value: UserType.admins, child: Text('Admins')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedUserType = value;
                            _applyFilters();
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12),
            Expanded(child: _buildUserList()),
          ],
        ),
      ),
    );
  }
}
