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
          'department': data['department'] ?? '',
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
        final department = (user['department'] ?? '').toLowerCase();
        return name.contains(query) || regNumber.contains(query) || department.contains(query);
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
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'view') {
                _viewUserDetails(user);
              } else if (value == 'edit') {
                _editUser(user);
              } else if (value == 'delete') {
                _deleteUser(user);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'view', child: Text('View Details')),
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
          onTap: () {
            // Optionally handle user tap
          },
        );
      },
    );
  }

  Future<void> _viewUserDetails(Map<String, dynamic> user) async {
    print('Viewing user details: $user'); // Debug print
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('User Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Text('Name: ${user['name'] ?? ''}'),
              if (user['regNumber'] != null && user['regNumber'].isNotEmpty)
                Text('Registration Number: ${user['regNumber']}'),
              if (user['department'] != null && user['department'].isNotEmpty)
                Text('Department: ${user['department']}'),
              if (user['email'] != null && user['email'].isNotEmpty)
                Text('Email: ${user['email']}'),
              Text('User Type: ${user['type'].toString().split('.').last}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editUser(Map<String, dynamic> user) async {
    final _formKey = GlobalKey<FormState>();
    final TextEditingController _nameController = TextEditingController(text: user['name'] ?? '');
    final TextEditingController _regNumberController = TextEditingController(text: user['regNumber'] ?? '');
    final TextEditingController _departmentController = TextEditingController(text: user['department'] ?? '');

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit User'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: 'Name'),
                  validator: (value) => value == null || value.isEmpty ? 'Enter name' : null,
                ),
                if (user['regNumber'] != null)
                  TextFormField(
                    controller: _regNumberController,
                    decoration: InputDecoration(labelText: 'Registration Number'),
                    validator: (value) => value == null || value.isEmpty ? 'Enter registration number' : null,
                  ),
                if (user['department'] != null)
                  TextFormField(
                    controller: _departmentController,
                    decoration: InputDecoration(labelText: 'Department'),
                    validator: (value) => value == null || value.isEmpty ? 'Enter department' : null,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState != null && _formKey.currentState!.validate()) {
                  try {
                    String collectionName = _getCollectionName(user['type']);
                    await FirebaseFirestore.instance.collection(collectionName).doc(user['id']).update({
                      'name': _nameController.text.trim(),
                      if (user['regNumber'] != null) 'regNumber': _regNumberController.text.trim(),
                      if (user['department'] != null) 'department': _departmentController.text.trim(),
                    });
                    Navigator.pop(context);
                    _fetchAllUsers();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update user: $e')));
                  }
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    bool confirmed = false;
    confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Delete User'),
              content: Text('Are you sure you want to delete ${user['name']}?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (confirmed) {
      try {
        String collectionName = _getCollectionName(user['type']);
        await FirebaseFirestore.instance.collection(collectionName).doc(user['id']).delete();
        _fetchAllUsers();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete user: $e')));
      }
    }
  }

  String _getCollectionName(UserType type) {
    switch (type) {
      case UserType.students:
        return 'students';
      case UserType.instructors:
        return 'instructors';
      case UserType.invigilators:
        return 'invigilators';
      case UserType.admins:
        return 'admins';
      default:
        return '';
    }
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
