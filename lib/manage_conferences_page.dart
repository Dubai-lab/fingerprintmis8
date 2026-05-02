import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageConferencesPage extends StatefulWidget {
  const ManageConferencesPage({Key? key}) : super(key: key);

  @override
  _ManageConferencesPageState createState() => _ManageConferencesPageState();
}

class _ManageConferencesPageState extends State<ManageConferencesPage> {
  final TextEditingController _conferenceNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime? _startDate;
  DateTime? _endDate;
  List<Map<String, dynamic>> _conferences = [];
  bool _isLoading = true;
  String _filter = 'all'; // 'all', 'ongoing', 'completed'

  @override
  void initState() {
    super.initState();
    _loadConferences();
  }

  Future<void> _loadConferences() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch all conferences without server-side filtering
      final querySnapshot = await FirebaseFirestore.instance
          .collection('conferences')
          .orderBy('startDate', descending: true)
          .get();

      var conferences = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        return {
          'id': doc.id,
          'conferenceName': data['conferenceName'] ?? '',
          'description': data['description'] ?? '',
          'startDate': data['startDate']?.toDate(),
          'endDate': data['endDate']?.toDate(),
          'status': data['status'] ?? 'scheduled',
          'createdAt': data['createdAt']?.toDate(),
        };
      }).toList();

      // Apply client-side filtering based on dates
      if (_filter == 'ongoing') {
        final now = DateTime.now();
        conferences = conferences.where((conf) {
          final startDate = conf['startDate'] as DateTime?;
          final endDate = conf['endDate'] as DateTime?;
          return startDate != null && 
                 endDate != null &&
                 startDate.isBefore(now) && 
                 endDate.isAfter(now);
        }).toList();
      } else if (_filter == 'completed') {
        final now = DateTime.now();
        conferences = conferences.where((conf) {
          final endDate = conf['endDate'] as DateTime?;
          return endDate != null && endDate.isBefore(now);
        }).toList();
      }

      // Sort by start date (newest first)
      conferences.sort((a, b) {
        if (a['startDate'] == null && b['startDate'] == null) return 0;
        if (a['startDate'] == null) return 1;
        if (b['startDate'] == null) return -1;
        return b['startDate'].compareTo(a['startDate']);
      });

      // Sort by start date (newest first)
      conferences.sort((a, b) {
        if (a['startDate'] == null && b['startDate'] == null) return 0;
        if (a['startDate'] == null) return 1;
        if (b['startDate'] == null) return -1;
        return b['startDate'].compareTo(a['startDate']);
      });

      setState(() {
        _conferences = conferences;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load conferences: $e')),
      );
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        // Auto-set end date to same day if not set or before start date
        if (_endDate == null || _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? (_startDate ?? DateTime.now()),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _createConference() async {
    final conferenceName = _conferenceNameController.text.trim();
    final description = _descriptionController.text.trim();

    if (conferenceName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a conference name')),
      );
      return;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end dates')),
      );
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date must be after or equal to start date')),
      );
      return;
    }

    try {
      await _firestore.collection('conferences').add({
        'conferenceName': conferenceName,
        'description': description,
        'startDate': _startDate,
        'endDate': _endDate,
        'status': 'scheduled',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _conferenceNameController.clear();
      _descriptionController.clear();
      setState(() {
        _startDate = null;
        _endDate = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Conference "$conferenceName" created successfully')),
      );

      _loadConferences();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create conference: $e')),
      );
    }
  }

  Future<void> _deleteConference(String conferenceId, String conferenceName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conference'),
        content: Text('Are you sure you want to delete "$conferenceName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('conferences').doc(conferenceId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Conference "$conferenceName" deleted successfully')),
        );
        _loadConferences();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete conference: $e')),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    final now = DateTime.now();
    if (_conferences.isNotEmpty) {
      final conference =
          _conferences.firstWhere((c) => c['status'] == status, orElse: () => {});
      if (conference.isNotEmpty) {
        if (conference['endDate'] != null && conference['endDate'].isBefore(now)) {
          return Colors.blue;
        } else if (conference['startDate'] != null &&
            conference['startDate'].isAfter(now)) {
          return Colors.green;
        } else if (conference['startDate'] != null &&
            conference['endDate'] != null &&
            conference['startDate'].isBefore(now) &&
            conference['endDate'].isAfter(now)) {
          return Colors.orange;
        }
      }
    }
    return Colors.grey;
  }

  String _getStatusText(String status) {
    return status == 'scheduled' ? 'Scheduled' : status;
  }

  String _getConferenceStatus(DateTime? startDate, DateTime? endDate) {
    if (startDate == null || endDate == null) return 'Unknown';
    final now = DateTime.now();
    if (endDate.isBefore(now)) {
      return 'Completed';
    } else if (startDate.isAfter(now)) {
      return 'Upcoming';
    } else {
      return 'Ongoing';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Conferences'),
        backgroundColor: Colors.deepPurple,
        elevation: 4,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Create Conference Section
          Card(
            margin: const EdgeInsets.all(16),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create New Conference',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _conferenceNameController,
                    decoration: InputDecoration(
                      labelText: 'Conference Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.event),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description (Optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.description),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _selectStartDate,
                          icon: const Icon(Icons.calendar_today),
                          label: Text(_startDate == null
                              ? 'Start Date'
                              : '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _selectEndDate,
                          icon: const Icon(Icons.calendar_today),
                          label: Text(_endDate == null
                              ? 'End Date'
                              : '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _createConference,
                      icon: const Icon(Icons.add),
                      label: const Text('Create Conference'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Filter Buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _filter == 'all' ? Colors.deepPurple : Colors.grey[300],
                      foregroundColor:
                          _filter == 'all' ? Colors.white : Colors.black,
                    ),
                    onPressed: () {
                      setState(() {
                        _filter = 'all';
                      });
                      _loadConferences();
                    },
                    child: const Text('All'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _filter == 'ongoing' ? Colors.orange : Colors.grey[300],
                      foregroundColor:
                          _filter == 'ongoing' ? Colors.white : Colors.black,
                    ),
                    onPressed: () {
                      setState(() {
                        _filter = 'ongoing';
                      });
                      _loadConferences();
                    },
                    child: const Text('Ongoing'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _filter == 'completed' ? Colors.blue : Colors.grey[300],
                      foregroundColor:
                          _filter == 'completed' ? Colors.white : Colors.black,
                    ),
                    onPressed: () {
                      setState(() {
                        _filter = 'completed';
                      });
                      _loadConferences();
                    },
                    child: const Text('Completed'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Conferences List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _conferences.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              'No conferences found',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _conferences.length,
                        itemBuilder: (context, index) {
                          final conference = _conferences[index];
                          final status = _getConferenceStatus(
                            conference['startDate'],
                            conference['endDate'],
                          );
                          final statusColor = status == 'Completed'
                              ? Colors.blue
                              : status == 'Ongoing'
                                  ? Colors.orange
                                  : Colors.green;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              conference['conferenceName'] ?? '',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            if (conference['description'] != null &&
                                                conference['description']
                                                    .isNotEmpty)
                                              Text(
                                                conference['description'],
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(color: statusColor),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(Icons.date_range,
                                          size: 16, color: Colors.grey[600]),
                                      const SizedBox(width: 8),
                                      Text(
                                        conference['startDate'] != null &&
                                                conference['endDate'] != null
                                            ? '${conference['startDate'].day}/${conference['startDate'].month}/${conference['startDate'].year} - ${conference['endDate'].day}/${conference['endDate'].month}/${conference['endDate'].year}'
                                            : 'No dates',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        onPressed: () => _deleteConference(
                                          conference['id'],
                                          conference['conferenceName'],
                                        ),
                                        icon: const Icon(Icons.delete),
                                        color: Colors.red,
                                        tooltip: 'Delete Conference',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _conferenceNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
