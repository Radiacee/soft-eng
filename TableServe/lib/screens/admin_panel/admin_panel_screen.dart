import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_message.dart';
import 'admin_notification.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  AdminPanelState createState() => AdminPanelState();
}

class AdminPanelState extends State<AdminPanel> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _selectedIndex = 0;
  DateTime selectedWeek = DateTime.now();
  List<DateTime> weeks = [];

  Future<void> _logout(BuildContext context) async {
    try {
      await _auth.signOut();
      Navigator.pushReplacementNamed(
          context, '/login'); // Redirect to login screen
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error: ${e.toString()}",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _listenForNotifications();
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message.data);
    });
    
  }

  void _listenForNotifications() {
    FirebaseFirestore.instance
        .collection('adminNotifications')
        .where('viewed', isEqualTo: false)
        .snapshots()
        .listen((QuerySnapshot snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          var data = change.doc.data() as Map<String, dynamic>;
          _showLocalNotification(data);
        }
      }
    });
  }

  void _showLocalNotification(Map<String, dynamic> data) {
    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 10,
        channelKey: 'high_importance_channel',
        title: data['type'] == 'newMessage' ? '${data['message']}' : 'Request',
        body: data['type'] == 'newMessage'
            ? data['message']
            : '${data['message']}',
        notificationLayout: NotificationLayout.Default,
        icon: 'resource://drawable/ic_launcher',
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    bool? shouldLogout = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Confirm Logout"),
          content: Text("Are you sure you want to logout?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text("Logout",
                  style: TextStyle(
                      color: Colors.red)), // Set the text color to red
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      _logout(context);
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  List<pw.Widget> buildWeeklyVisitors(Map<int, List<String>> weeklyVisitors) {
    List<pw.Widget> widgets = [];
    var sortedEntries = weeklyVisitors.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final uniqueVisitors = <String>{};

    for (var entry in sortedEntries) {
      widgets.add(
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Week ${entry.key}:', style: pw.TextStyle(fontSize: 18)),
            pw.SizedBox(height: 10),
            if (entry.value.isEmpty)
              pw.Text('None', style: pw.TextStyle(fontSize: 16)),
            if (entry.value.isNotEmpty)
              ...entry.value
                  .where((visitor) {
                    // Check if the visitor is unique
                    final isUnique = uniqueVisitors.add(visitor);
                    return isUnique;
                  })
                  .map((visitor) =>
                      pw.Text(visitor, style: pw.TextStyle(fontSize: 16)))
                  .toList(),
            pw.SizedBox(height: 20),
          ],
        ),
      );
    }

    return widgets;
  }

  Future<void> _generatePdf(
      Map<String, Map<String, int>> overallData,
      Map<String, Map<String, Map<String, int>>> dateWiseData,
      int totalRequestsCount,
      int totalUsersCount,
      Map<int, List<String>> weeklyVisitors,
      bool isVisitorStatistics) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (!isVisitorStatistics) ...[
                if (selectedDate.year == 2000) ...[
                  pw.Text('Overall Statistics',
                      style: pw.TextStyle(fontSize: 24)),
                  pw.SizedBox(height: 20),
                  pw.Text('Request Count by Table',
                      style: pw.TextStyle(fontSize: 18)),
                  pw.SizedBox(height: 10),
                  pw.TableHelper.fromTextArray(
                    headers: ['Table ID', 'Request Count'],
                    data: overallData.entries.map((entry) {
                      return [
                        entry.key,
                        entry.value['requestCount'].toString()
                      ];
                    }).toList(),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text('User Count by Table',
                      style: pw.TextStyle(fontSize: 18)),
                  pw.SizedBox(height: 10),
                  pw.TableHelper.fromTextArray(
                    headers: ['Table ID', 'User Count'],
                    data: overallData.entries.map((entry) {
                      return [entry.key, entry.value['usersCount'].toString()];
                    }).toList(),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text('Total Requests: $totalRequestsCount',
                      style: pw.TextStyle(fontSize: 18)),
                  pw.SizedBox(height: 10),
                  pw.Text('Total Users: $totalUsersCount',
                      style: pw.TextStyle(fontSize: 18)),
                ],
                if (selectedDate.year != 2000) ...[
                  pw.Text('TableServe Statistics',
                      style: pw.TextStyle(fontSize: 24)),
                  pw.SizedBox(height: 20),
                  ...dateWiseData.entries.map((dateEntry) {
                    int dateTotalRequests = dateEntry.value.values
                        .fold(0, (sum, entry) => sum + entry['requestCount']!);
                    int dateTotalUsers = dateEntry.value.values
                        .fold(0, (sum, entry) => sum + entry['usersCount']!);
                    return pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Date: ${dateEntry.key}',
                            style: pw.TextStyle(fontSize: 18)),
                        pw.SizedBox(height: 10),
                        pw.Text('Request Count',
                            style: pw.TextStyle(fontSize: 16)),
                        pw.SizedBox(height: 10),
                        pw.TableHelper.fromTextArray(
                          headers: ['Table ID', 'Request Count'],
                          data: dateEntry.value.entries.map((entry) {
                            return [
                              entry.key,
                              entry.value['requestCount'].toString()
                            ];
                          }).toList(),
                        ),
                        pw.SizedBox(height: 10),
                        pw.Text('User Count',
                            style: pw.TextStyle(fontSize: 16)),
                        pw.SizedBox(height: 10),
                        pw.TableHelper.fromTextArray(
                          headers: ['Table ID', 'User Count'],
                          data: dateEntry.value.entries.map((entry) {
                            return [
                              entry.key,
                              entry.value['usersCount'].toString()
                            ];
                          }).toList(),
                        ),
                        pw.SizedBox(height: 10),
                        pw.Text('Total Requests: $dateTotalRequests',
                            style: pw.TextStyle(fontSize: 16)),
                        pw.SizedBox(height: 10),
                        pw.Text('Total Users: $dateTotalUsers',
                            style: pw.TextStyle(fontSize: 16)),
                        pw.SizedBox(height: 20),
                      ],
                    );
                  }).toList(),
                ],
              ],
              if (isVisitorStatistics) ...[
                pw.Text(
                    'Visitors for ${DateFormat('MMMM').format(selectedDate)}',
                    style: pw.TextStyle(fontSize: 24)),
                pw.SizedBox(height: 10),
                ...buildWeeklyVisitors(weeklyVisitors),
              ],
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File("${output.path}/statistics_$timestamp.pdf");
    await file.writeAsBytes(await pdf.save());

// Provide an option to download the PDF
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('PDF generated successfully!'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () async {
            OpenFile.open(file.path);
          },
        ),
      ),
    );
  }

  bool _isLoading = false;

  void _downloadStatistics(bool isVisitorStatistics) async {
    setState(() {
      _isLoading = true; // Show loading indicator
    });

    // Aggregate data for analytics collection
    Map<String, Map<String, int>> overallData = {};
    Map<String, Map<String, Map<String, int>>> dateWiseData = {};
    Map<int, List<String>> weeklyVisitors = {};
    Map<String, String> userLoginDates = {};

    DateTime startOfDay;
    DateTime endOfDay;

    if (selectedDate.year == 2000) {
      // Handle the "Overall" option
      startOfDay = DateTime(2000);
      endOfDay = DateTime(2101);
    } else {
      startOfDay =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      endOfDay = startOfDay.add(Duration(days: 1));
    }

    // Fetch data from Firestore and aggregate it
    QuerySnapshot analyticsSnapshot = await FirebaseFirestore.instance
        .collection('analytics')
        .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
        .where('timestamp', isLessThan: endOfDay)
        .get();

    int totalRequestsCount = 0;
    int totalUsersCount = 0;

    for (var doc in analyticsSnapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      String tableId = data['tableId'] ?? 'Unknown';
      int requestCount = data['requestCount'] ?? 0;
      int usersCount = data['usersCount'] ?? 0;
      DateTime timestamp = (data['timestamp'] as Timestamp).toDate();
      String dateKey = DateFormat('yyyy-MM-dd').format(timestamp);

      if (!overallData.containsKey(tableId)) {
        overallData[tableId] = {'requestCount': 0, 'usersCount': 0};
      }

      overallData[tableId]!['requestCount'] =
          (overallData[tableId]!['requestCount'] ?? 0) + requestCount;
      overallData[tableId]!['usersCount'] =
          (overallData[tableId]!['usersCount'] ?? 0) + usersCount;

      totalRequestsCount += requestCount;
      totalUsersCount += usersCount;

      if (selectedDate.year != 2000) {
        if (!dateWiseData.containsKey(dateKey)) {
          dateWiseData[dateKey] = {};
        }

        if (!dateWiseData[dateKey]!.containsKey(tableId)) {
          dateWiseData[dateKey]![tableId] = {
            'requestCount': 0,
            'usersCount': 0
          };
        }

        dateWiseData[dateKey]![tableId]!['requestCount'] =
            (dateWiseData[dateKey]![tableId]!['requestCount'] ?? 0) +
                requestCount;
        dateWiseData[dateKey]![tableId]!['usersCount'] =
            (dateWiseData[dateKey]![tableId]!['usersCount'] ?? 0) + usersCount;
      }
    }

    if (isVisitorStatistics) {
      // Fetch visitor data for the selected month
      DateTime firstDayOfMonth =
          DateTime(selectedDate.year, selectedDate.month, 1);
      DateTime lastDayOfMonth =
          DateTime(selectedDate.year, selectedDate.month + 1, 0);

      QuerySnapshot visitorsSnapshot = await FirebaseFirestore.instance
          .collection('adminAnalytics')
          .where('timestamp', isGreaterThanOrEqualTo: firstDayOfMonth)
          .where('timestamp', isLessThanOrEqualTo: lastDayOfMonth)
          .get();

      for (var doc in visitorsSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        var userNames = data['userNames'];
        DateTime timestamp = (data['timestamp'] as Timestamp).toDate();
        int weekOfMonth = ((timestamp.day - 1) / 7).floor() + 1;

        if (!weeklyVisitors.containsKey(weekOfMonth)) {
          weeklyVisitors[weekOfMonth] = [];
        }

        if (userNames is List) {
          for (var name in userNames) {
            weeklyVisitors[weekOfMonth]!.add(name);
            userLoginDates[name] = DateFormat('yyyy-MM-dd').format(timestamp);
          }
        } else if (userNames is Map) {
          userNames.forEach((userName, userEmail) {
            weeklyVisitors[weekOfMonth]!.add(userName);
            userLoginDates[userName] =
                DateFormat('yyyy-MM-dd').format(timestamp);
          });
        }
      }

      // Ensure all weeks are represented and sorted
      for (int i = 1; i <= 4; i++) {
        if (!weeklyVisitors.containsKey(i)) {
          weeklyVisitors[i] = [];
        }
      }

      // Create a document in adminAnalytics with user names and login dates
      await FirebaseFirestore.instance.collection('adminAnalytics').add({
        'month': DateFormat('MMMM').format(selectedDate),
        'year': selectedDate.year,
        'userNames': userLoginDates,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    // Generate and download the PDF
    await _generatePdf(overallData, dateWiseData, totalRequestsCount,
        totalUsersCount, weeklyVisitors, isVisitorStatistics);

    setState(() {
      _isLoading = false; // Hide loading indicator
    });
  }

  void _showDownloadOptions() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Download Options"),
          content: const Text("Choose the type of statistics to download:"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _downloadStatistics(false); // Download overall statistics
              },
              child: const Text("Overall Statistics"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _downloadStatistics(true); // Download visitor statistics
              },
              child: const Text("Visitor Statistics"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        title: Text("TableServe",
            style: TextStyle(
              color: const Color(0xffD4C4AB),
              fontSize: _selectedIndex == 2 ? 24 : 32,
              fontFamily: "RubikOne",
            )),
        centerTitle: true,
        leading: IconButton(
          icon: Transform.rotate(
            angle: 3.14, // 180 degrees in radians
            child: Icon(Icons.logout),
          ),
          onPressed: () => _confirmLogout(context),
        ),
        actions: [
          if (_selectedIndex == 2)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: InkWell(
                onTap: () => _showDateOptions(context),
                hoverColor: Colors.grey.withOpacity(0.2),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today),
                    SizedBox(
                        width: 4), // Add some space between the icon and text
                    Text(
                      selectedDate.year == 2000
                          ? 'Overall'
                          : DateFormat('MM/dd/yyyy').format(selectedDate),
                      style: const TextStyle(color: Colors.black, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          StreamBuilder(
            stream: FirebaseFirestore.instance
                .collection('adminNotifications')
                .where('viewed', isEqualTo: false)
                .snapshots(),
            builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                return IconButton(
                  icon: Stack(
                    children: [
                      const Icon(Icons.notifications),
                      Positioned(
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 12,
                            minHeight: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminNotificationScreen(),
                      ),
                    );
                  },
                );
              } else {
                return IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminNotificationScreen(),
                      ),
                    );
                  },
                );
              }
            },
          ),
        ],
        toolbarHeight: 80,
        flexibleSpace: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              height: 5,
              color: Color(0xFF80ACB2),
            ),
            Container(
              height: 5,
              color: Color(0xFFA3C8CE),
            ),
            Container(
              height: 5,
              color: Color(0xFFD9D3C1),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          _selectedIndex == 0
              ? _buildActiveTables()
              : _selectedIndex == 1
                  ? _buildRequestList()
                  : _buildAnalytics(),
          if (_selectedIndex == 2)
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: FloatingActionButton(
                  onPressed: _isLoading ? null : _showDownloadOptions,
                  backgroundColor: Colors.blue,
                  child: _isLoading
                      ? CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      : Icon(Icons.download),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.table_chart),
            label: 'Tables',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.room_service_rounded),
            label: 'Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildActiveTables() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('activeTables').snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No active tables"));
        }

        return Column(
          children: [
            Text(
              'Tables',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF316175),
                fontSize: 32,
                fontFamily: 'RubikOne',
              ),
            ),
            Expanded(
              child: ListView(
                children: snapshot.data!.docs.map((doc) {
                  String tableId = doc.id;
                  return ListTile(
                    title: Text(
                      {
                            "table_1": "Table 1",
                            "table_2": "Table 2",
                            "table_3": "Table 3",
                            "table_4": "Table 4",
                            "table_5": "Table 5",
                          }[tableId] ??
                          tableId, // Default to tableId if not found in the map
                    ),
                    // title: Text("$tableId"), // Display the tableId as the title
                    trailing: StreamBuilder(
                      stream: FirebaseFirestore.instance
                          .collection('guestRequests')
                          .where('tableId', isEqualTo: tableId)
                          .where('status', isEqualTo: 'pending')
                          .snapshots(),
                      builder: (context,
                          AsyncSnapshot<QuerySnapshot> requestSnapshot) {
                        if (requestSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }
                        int pendingCount =
                            requestSnapshot.data?.docs.length ?? 0;
                        return Stack(
                          children: [
                            const Icon(Icons.table_restaurant, size: 30),
                            if (pendingCount > 0)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 20,
                                    minHeight: 20,
                                  ),
                                  child: Text(
                                    '$pendingCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              RequestDetailsScreen(tableId: tableId),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            )
          ],
        );
      },
    );
  }

  Widget _buildRequestList() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('requestList').snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AddRequestDialog();
                        },
                      );
                    },
                    child: Row(
                      children: [
                        Icon(Icons.add, color: Colors.blue),
                        SizedBox(
                            width:
                                8), // Optional: Adds space between icon and text
                        Text('Add Request'),
                      ],
                    ),
                  )
                ],
              ),
            ],
          );
        }

        return Column(
          children: [
            Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      'Request List',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF316175),
                        fontSize: 22,
                        fontFamily: 'RubikOne',
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  child: PopupMenuButton<String>(
                    icon: Icon(Icons.menu,
                        color: Colors.blue), // Burger menu icon
                    onSelected: (String result) {
                      switch (result) {
                        case 'Add Request':
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AddRequestDialog();
                            },
                          );
                          break;
                        case 'Edit FAQ':
                          _showFaqEditDialog();
                          break;
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'Add Request',
                        child: Text('Add Request'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'Edit FAQ',
                        child: Text('Edit FAQ'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                children: snapshot.data!.docs.map((doc) {
                  // Extracting the request details
                  String requestType = doc['type'] ?? 'Unknown';
                  String information =
                      doc['information'] ?? 'No information provided';
                  List<String> items = List<String>.from(doc['items']);
                  String itemsJoined = items.join(',');

                  return Card(
                    margin: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 16.0),
                    elevation: 4,
                    child: ListTile(
                      title: Text(requestType,
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(information),
                          if (itemsJoined != "") ...[
                            const SizedBox(height: 8),
                            Text("Items: ${items.join(', ')}"),
                          ],
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Edit icon
                          IconButton(
                            icon: Icon(Icons.edit, color: Colors.orange),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return EditRequestDialog(
                                      doc: doc.data() as Map<String, dynamic>);
                                },
                              );
                            },
                          ),
                          // Delete icon
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              _showDeleteRequestConfirmationDialog(
                                  context, doc.id);
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        // Add navigation or actions on tap if necessary
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showFaqEditDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            height: MediaQuery.of(context).size.height *
                0.8, // Set height to 80% of screen height
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Edit FAQs",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('faqs')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.data!.docs.isEmpty) {
                        return const Center(
                            child: Text("No FAQs available. Add one!"));
                      }

                      final faqs = snapshot.data!.docs;

                      return ListView.builder(
                        itemCount: faqs.length,
                        itemBuilder: (context, index) {
                          var faq = faqs[index];
                          var data = faq.data() as Map<String, dynamic>;

                          return ListTile(
                            title: Text(data['title'] ?? 'No Title'),
                            subtitle: Text(data['content'] ?? 'No Content'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue),
                                  onPressed: () {
                                    _showEditDialog(faq.id, data);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () {
                                    _showDeleteFaqConfirmationDialog(
                                        context, faq.id);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text("Close"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _showAddFaqDialog();
                      },
                      child: const Text("Add FAQ"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteFaqConfirmationDialog(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete FAQ"),
          content: const Text("Are you sure you want to delete this FAQ?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                FirebaseFirestore.instance
                    .collection('faqs')
                    .doc(docId)
                    .delete()
                    .then((_) {
                  Navigator.of(context).pop();
                  Fluttertoast.showToast(
                    msg: "FAQ deleted successfully",
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                    timeInSecForIosWeb: 1,
                    backgroundColor: Colors.green,
                    textColor: Colors.white,
                    fontSize: 16.0,
                  );
                }).catchError((error) {
                  Fluttertoast.showToast(
                    msg: "Failed to delete FAQ: $error",
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                    timeInSecForIosWeb: 1,
                    backgroundColor: Colors.red,
                    textColor: Colors.white,
                    fontSize: 16.0,
                  );
                });
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  void _showEditDialog(String docId, Map<String, dynamic> data) {
    TextEditingController titleController =
        TextEditingController(text: data['title']);
    TextEditingController contentController =
        TextEditingController(text: data['content']);
    TextEditingController detailsController =
        TextEditingController(text: data['details']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Editing"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(labelText: 'Content'),
              ),
              TextField(
                controller: detailsController,
                decoration: const InputDecoration(labelText: 'Details'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                FirebaseFirestore.instance
                    .collection('faqs')
                    .doc(docId)
                    .update({
                  'title': titleController.text,
                  'content': contentController.text,
                  'details': detailsController.text,
                }).then((_) {
                  Navigator.of(context).pop();
                  Fluttertoast.showToast(
                    msg: "FAQ updated successfully",
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                    timeInSecForIosWeb: 1,
                    backgroundColor: Colors.green,
                    textColor: Colors.white,
                    fontSize: 16.0,
                  );
                }).catchError((error) {
                  Fluttertoast.showToast(
                    msg: "Failed to update FAQ: $error",
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                    timeInSecForIosWeb: 1,
                    backgroundColor: Colors.red,
                    textColor: Colors.white,
                    fontSize: 16.0,
                  );
                });
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void _showAddFaqDialog() {
    TextEditingController titleController = TextEditingController();
    TextEditingController contentController = TextEditingController();
    TextEditingController detailsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add FAQ"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(labelText: 'Content'),
              ),
              TextField(
                controller: detailsController,
                decoration: const InputDecoration(labelText: 'Details'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                FirebaseFirestore.instance.collection('faqs').add({
                  'title': titleController.text,
                  'content': contentController.text,
                  'details': detailsController.text,
                }).then((_) {
                  Navigator.of(context).pop();
                  Fluttertoast.showToast(
                    msg: "FAQ added successfully",
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                    timeInSecForIosWeb: 1,
                    backgroundColor: Colors.green,
                    textColor: Colors.white,
                    fontSize: 16.0,
                  );
                }).catchError((error) {
                  Fluttertoast.showToast(
                    msg: "Failed to add FAQ: $error",
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                    timeInSecForIosWeb: 1,
                    backgroundColor: Colors.red,
                    textColor: Colors.white,
                    fontSize: 16.0,
                  );
                });
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteRequestConfirmationDialog(
      BuildContext context, String docId) {
    TextEditingController confirmationController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Request"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Type 'DELETE' to confirm deleting this request."),
              const SizedBox(height: 10),
              TextField(
                controller: confirmationController,
                decoration: const InputDecoration(
                  labelText: 'Confirmation',
                  hintText: 'DELETE',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (confirmationController.text == 'DELETE') {
                  FirebaseFirestore.instance
                      .collection('requestList')
                      .doc(docId)
                      .delete()
                      .then((_) {
                    Fluttertoast.showToast(
                      msg: "Request deleted successfully",
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                      timeInSecForIosWeb: 1,
                      backgroundColor: Colors.green,
                      textColor: Colors.white,
                      fontSize: 16.0,
                    );
                  }).catchError((error) {
                    Fluttertoast.showToast(
                      msg: "Failed to delete request",
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                      timeInSecForIosWeb: 1,
                      backgroundColor: Colors.red,
                      textColor: Colors.white,
                      fontSize: 16.0,
                    );
                  });
                  FirebaseFirestore.instance
                      .collection('globalAnalytics')
                      .doc(docId)
                      .delete()
                      .then((_) {
                    Fluttertoast.showToast(
                      msg: "Request from Analytics deleted successfully",
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                      timeInSecForIosWeb: 1,
                      backgroundColor: Colors.green,
                      textColor: Colors.white,
                      fontSize: 16.0,
                    );
                  }).catchError((error) {
                    Fluttertoast.showToast(
                      msg: "Failed to delete request from Analytics",
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                      timeInSecForIosWeb: 1,
                      backgroundColor: Colors.red,
                      textColor: Colors.white,
                      fontSize: 16.0,
                    );
                  });
                  Navigator.of(context).pop();
                } else {
                  Fluttertoast.showToast(
                    msg: "Incorrect confirmation text",
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                    timeInSecForIosWeb: 1,
                    backgroundColor: Colors.red,
                    textColor: Colors.white,
                    fontSize: 16.0,
                  );
                }
              },
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all(Colors.red),
              ),
              child:
                  const Text("DELETE", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // analytics
  DateTime selectedDate = DateTime.now();

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.year == 2000 ? DateTime.now() : selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        print("Selected date: $selectedDate"); // Debug print
      });
    }
  }

  void _showDateOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Select Date"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text("Overall"),
                onTap: () {
                  setState(() {
                    selectedDate = DateTime(2000); // Set to a very early date
                    print("Selected Overall"); // Debug print
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: const Text("Pick a date"),
                onTap: () {
                  Navigator.of(context).pop();
                  _selectDate(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalytics() {
    DateTime startOfDay;
    DateTime endOfDay;

    if (selectedDate.year == 2000) {
      // Handle the "Overall" option
      startOfDay = DateTime(2000);
      endOfDay = DateTime(2101);
      print("Using Overall date range"); // Debug print
    } else {
      startOfDay =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      endOfDay = startOfDay.add(Duration(days: 1));
      print(
          "Using selected date range: $startOfDay to $endOfDay"); // Debug print
    }

    return Column(
      children: [
        Expanded(
          child: StreamBuilder(
            stream: FirebaseFirestore.instance
                .collection('analytics')
                .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
                .where('timestamp', isLessThan: endOfDay)
                .snapshots(),
            builder: (context, AsyncSnapshot<QuerySnapshot> analyticsSnapshot) {
              if (analyticsSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!analyticsSnapshot.hasData ||
                  analyticsSnapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No analytics data"));
              }

              return StreamBuilder(
                stream: FirebaseFirestore.instance
                    .collection('globalAnalytics')
                    .where('timestamp',
                        isGreaterThanOrEqualTo:
                            startOfDay) // Filter by timestamp
                    .where('timestamp',
                        isLessThan: endOfDay) // Filter by timestamp
                    .snapshots(),
                builder: (context,
                    AsyncSnapshot<QuerySnapshot> globalAnalyticsSnapshot) {
                  if (globalAnalyticsSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!globalAnalyticsSnapshot.hasData ||
                      globalAnalyticsSnapshot.data!.docs.isEmpty) {
                    return const Center(
                        child: Text("No available analytics data"));
                  }

                  // Aggregate data for analytics collection
                  Map<String, Map<String, int>> aggregatedData = {};
                  int totalUsersCount = 0;
                  int totalRequestsCount = 0;

                  for (var doc in analyticsSnapshot.data!.docs) {
                    var data = doc.data() as Map<String, dynamic>;
                    String tableId = data['tableId'] ?? 'Unknown';
                    int requestCount = data['requestCount'] ?? 0;
                    int usersCount = data['usersCount'] ?? 0;

                    if (!aggregatedData.containsKey(tableId)) {
                      aggregatedData[tableId] = {
                        'requestCount': 0,
                        'usersCount': 0
                      };
                    }

                    aggregatedData[tableId]!['requestCount'] =
                        (aggregatedData[tableId]!['requestCount'] ?? 0) +
                            requestCount;
                    aggregatedData[tableId]!['usersCount'] =
                        (aggregatedData[tableId]!['usersCount'] ?? 0) +
                            usersCount;

                    totalRequestsCount += requestCount;
                    totalUsersCount += usersCount;
                  }

                  List<_ChartData> requestData =
                      aggregatedData.entries.map((entry) {
                    return _ChartData(entry.key, entry.value['requestCount']!);
                  }).toList();

                  List<_ChartData> userData =
                      aggregatedData.entries.map((entry) {
                    return _ChartData(entry.key, entry.value['usersCount']!);
                  }).toList();

                  // Aggregate data for globalAnalytics collection
                  Map<String, int> requestTypeCounts = {};
                  for (var doc in globalAnalyticsSnapshot.data!.docs) {
                    var data = doc.data() as Map<String, dynamic>;
                    // Iterate over each field in the document
                    data.forEach((key, value) {
                      if (value is int) {
                        if (!requestTypeCounts.containsKey(key)) {
                          requestTypeCounts[key] = 0;
                        }
                        requestTypeCounts[key] =
                            requestTypeCounts[key]! + value;
                      }
                    });
                  }

                  List<_ChartData> requestTypeData =
                      requestTypeCounts.entries.map((entry) {
                    return _ChartData(entry.key, entry.value);
                  }).toList();

                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        // Display Total Counts
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Total Requests
                            Container(
                              // width: 200,
                              padding: const EdgeInsets.all(8),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.blue),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "$totalRequestsCount",
                                    style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue),
                                  ),
                                  const Text(
                                    "Total Requests",
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            // Total Users
                            Container(
                              // width: 200,
                              padding: const EdgeInsets.all(8),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.green),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "$totalUsersCount",
                                    style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green),
                                  ),
                                  const Text(
                                    "Total Users",
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),
                        const Text(
                          "Request Count by Table",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 5),
                        SizedBox(
                          height: 300,
                          child: SfCartesianChart(
                            primaryXAxis: CategoryAxis(),
                            series: <ChartSeries>[
                              ColumnSeries<_ChartData, String>(
                                dataSource: requestData,
                                xValueMapper: (_ChartData data, _) =>
                                    data.tableId,
                                yValueMapper: (_ChartData data, _) =>
                                    data.count,
                                color: Colors.blue,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "User Count by Table",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 5),
                        SizedBox(
                          height: 300,
                          child: SfCartesianChart(
                            primaryXAxis: CategoryAxis(),
                            series: <ChartSeries>[
                              ColumnSeries<_ChartData, String>(
                                dataSource: userData,
                                xValueMapper: (_ChartData data, _) =>
                                    data.tableId,
                                yValueMapper: (_ChartData data, _) =>
                                    data.count,
                                color: Colors.green,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Request Type Frequency",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 5),
                        SizedBox(
                          height: 500,
                          child: SfCircularChart(
                            legend: Legend(
                              isVisible: true,
                              alignment: ChartAlignment.center,
                              position: LegendPosition.bottom,
                              orientation: LegendItemOrientation.vertical,
                              overflowMode: LegendItemOverflowMode.scroll,
                              itemPadding: 10,
                              textStyle: TextStyle(
                                fontSize: 16, // Set your desired font size here
                              ),
                            ),
                            series: <CircularSeries>[
                              PieSeries<_ChartData, String>(
                                dataSource: requestTypeData,
                                xValueMapper: (_ChartData data, _) =>
                                    data.tableId,
                                yValueMapper: (_ChartData data, _) =>
                                    data.count,
                                dataLabelSettings:
                                    const DataLabelSettings(isVisible: true),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class AddRequestDialog extends StatefulWidget {
  const AddRequestDialog({super.key});

  @override
  AddRequestDialogState createState() => AddRequestDialogState();
}

// add request for admin
class AddRequestDialogState extends State<AddRequestDialog> {
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _informationController = TextEditingController();
  final TextEditingController _itemController = TextEditingController();
  List<String> _items = [];

  void _addItem() {
    setState(() {
      if (_itemController.text.isNotEmpty) {
        _items.add(_itemController.text);
        _itemController.clear();
      }
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Create New Request",
          style: TextStyle(
            color: Color(0xFF316175),
            fontFamily: "RubikOne",
          )),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _typeController,
              decoration: InputDecoration(labelText: 'Request'),
            ),
            TextField(
              controller: _informationController,
              decoration: InputDecoration(labelText: 'Information'),
            ),
            TextField(
                controller: _itemController,
                decoration: InputDecoration(
                  labelText: 'Add Item',
                  suffixIcon: IconButton(
                    icon: Icon(Icons.add),
                    onPressed: _addItem,
                  ),
                )),
            SizedBox(height: 10),
            Column(
              children: _items.map((item) {
                int index = _items.indexOf(item);
                return ListTile(
                  title: Text(item),
                  trailing: IconButton(
                    icon: Icon(Icons.remove),
                    onPressed: () => _removeItem(index),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            String type = _typeController.text;
            String information = _informationController.text;
            List<String> items = List.from(_items);
            if (_items.isEmpty) {
              items = [];
            }

            if (type.isEmpty || information.isEmpty) {
              Fluttertoast.showToast(
                msg: "Request type and information cannot be empty",
                toastLength: Toast.LENGTH_SHORT,
                gravity: ToastGravity.BOTTOM,
                timeInSecForIosWeb: 1,
                backgroundColor: Colors.red,
                textColor: Colors.white,
                fontSize: 16.0,
              );
              return;
            }

            var existingDoc = await FirebaseFirestore.instance
                .collection('requestList')
                .doc(type)
                .get();

            if (existingDoc.exists) {
              Fluttertoast.showToast(
                msg: "A request with this type already exists",
                toastLength: Toast.LENGTH_SHORT,
                gravity: ToastGravity.BOTTOM,
                timeInSecForIosWeb: 1,
                backgroundColor: Colors.red,
                textColor: Colors.white,
                fontSize: 16.0,
              );
            } else {
              // Add request with 'type' as document ID
              FirebaseFirestore.instance
                  .collection('requestList')
                  .doc(type)
                  .set({
                'type': type,
                'information': information,
                'items': items.isEmpty ? [] : items,
              }).then((_) {
                Fluttertoast.showToast(
                  msg: "Request added successfully",
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                  timeInSecForIosWeb: 1,
                  backgroundColor: Colors.green,
                  textColor: Colors.white,
                  fontSize: 16.0,
                );
              }).catchError((error) {
                Fluttertoast.showToast(
                  msg: "Failed to add request",
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                  timeInSecForIosWeb: 1,
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                  fontSize: 16.0,
                );
              });
              // add request to the analytics
              FirebaseFirestore.instance
                  .collection('globalAnalytics')
                  .doc(type)
                  .set({
                type: 0,
              }).then((_) {
                Navigator.of(context).pop();
                Fluttertoast.showToast(
                  msg: "Request added to Analytics",
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                  timeInSecForIosWeb: 1,
                  backgroundColor: Colors.green,
                  textColor: Colors.white,
                  fontSize: 16.0,
                );
              }).catchError((error) {
                Fluttertoast.showToast(
                  msg: "Failed to add request to Analytics",
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                  timeInSecForIosWeb: 1,
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                  fontSize: 16.0,
                );
              });
            }
          },
          child: Text("Save"),
        ),
      ],
    );
  }
}

class EditRequestDialog extends StatefulWidget {
  final Map<String, dynamic> doc; // Accept doc as a parameter

  const EditRequestDialog({super.key, required this.doc});

  @override
  EditRequestDialogState createState() => EditRequestDialogState();
}

class EditRequestDialogState extends State<EditRequestDialog> {
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _informationController = TextEditingController();
  final TextEditingController _itemController = TextEditingController();
  List<String> _items = [];

  @override
  void initState() {
    super.initState();
    // Initialize controllers with current doc values
    _typeController.text = widget.doc['type'];
    _informationController.text = widget.doc['information'];
    _items = List<String>.from(widget.doc['items'] ?? []);
  }

  void _addItem() {
    setState(() {
      if (_itemController.text.isNotEmpty) {
        _items.add(_itemController.text);
        _itemController.clear();
      }
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Edit Request",
          style: TextStyle(
            color: Color(0xFF316175),
            fontFamily: "RubikOne",
          )),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _typeController,
              decoration: InputDecoration(labelText: 'Request'),
            ),
            TextField(
              controller: _informationController,
              decoration: InputDecoration(labelText: 'Information'),
            ),
            TextField(
              controller: _itemController,
              decoration: InputDecoration(
                labelText: 'Add Item',
                suffixIcon: IconButton(
                  icon: Icon(Icons.add),
                  onPressed: _addItem,
                ),
              ),
            ),
            SizedBox(height: 10),
            Column(
              children: _items.map((item) {
                int index = _items.indexOf(item);
                return ListTile(
                  title: Text(item),
                  trailing: IconButton(
                    icon: Icon(Icons.remove),
                    onPressed: () => _removeItem(index),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            String type = _typeController.text;
            String information = _informationController.text;
            List<String> items = List.from(_items);

            if (type.isEmpty || information.isEmpty) {
              Fluttertoast.showToast(
                msg: "Request type and information cannot be empty",
                toastLength: Toast.LENGTH_SHORT,
                gravity: ToastGravity.BOTTOM,
                timeInSecForIosWeb: 1,
                backgroundColor: Colors.red,
                textColor: Colors.white,
                fontSize: 16.0,
              );
              return;
            }
            // Logic to update existing document with new data
            await FirebaseFirestore.instance
                .collection('requestList')
                .doc(widget.doc['type']) // Use old type as doc ID
                .delete(); // Delete old document

            // Add the updated request to Firestore
            FirebaseFirestore.instance.collection('requestList').doc(type).set({
              'type': type,
              'information': information,
              'items': items.isEmpty ? [] : items,
            }).then((_) {
              Navigator.of(context).pop();
              Fluttertoast.showToast(
                msg: "Request updated successfully",
                toastLength: Toast.LENGTH_SHORT,
                gravity: ToastGravity.BOTTOM,
                timeInSecForIosWeb: 1,
                backgroundColor: Colors.green,
                textColor: Colors.white,
                fontSize: 16.0,
              );
            }).catchError((error) {
              Fluttertoast.showToast(
                msg: "Failed to update request",
                toastLength: Toast.LENGTH_SHORT,
                gravity: ToastGravity.BOTTOM,
                timeInSecForIosWeb: 1,
                backgroundColor: Colors.red,
                textColor: Colors.white,
                fontSize: 16.0,
              );
            });

            // Update global analytics
            var oldDoc = await FirebaseFirestore.instance
                .collection('globalAnalytics')
                .doc(widget.doc['type'])
                .get();

            if (oldDoc.exists) {
              var requestTypeValue = oldDoc.data()?[widget.doc['type']];
              // Now delete the old document
              await FirebaseFirestore.instance
                  .collection('globalAnalytics')
                  .doc(widget.doc['type'])
                  .delete();
              await FirebaseFirestore.instance
                  .collection('globalAnalytics')
                  .doc(type) // Set the new type in global analytics
                  .set({type: requestTypeValue});
            }
          },
          child: Text("Save"),
        ),
      ],
    );
  }
}

class _ChartData {
  _ChartData(this.tableId, this.count);

  final String tableId;
  final int count;
}

class RequestDetailsScreen extends StatefulWidget {
  final String tableId;

  const RequestDetailsScreen({required this.tableId, super.key});

  @override
  RequestDetailsScreenState createState() => RequestDetailsScreenState();
}

class RequestDetailsScreenState extends State<RequestDetailsScreen>
    with SingleTickerProviderStateMixin {
  String userName = "Guest";
  String userEmail = "";
  late TabController _tabController;
  String? _selectedTableId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _selectedTableId = widget.tableId;
    _fetchUserName();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserName() async {
    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('activeTables')
        .doc(widget.tableId)
        .get();

    if (doc.exists && doc.data() != null) {
      var data = doc.data() as Map<String, dynamic>;
      if (data.containsKey('userNames')) {
        Map<String, dynamic> userNames = data['userNames'];
        if (userNames.isNotEmpty) {
          setState(() {
            String userNameWithEmail = userNames.keys.first;
            List<String> parts = userNameWithEmail.split(':');
            if (parts.length == 2) {
              userName = parts[0].trim();
              userEmail = parts[1].trim();
            }
          });
        }
      }
    }
  }

  void _updateRequestStatus(String requestId, String status) async {
    try {
      // Fetch the current user's email (admin's email)
      String? adminEmail = FirebaseAuth.instance.currentUser?.email;

      if (adminEmail == null) {
        print("No admin email found.");
        return;
      }

      // Debug: Print the request ID and status being updated
      print("Updating request ID: $requestId to status: $status");

      // Fetch the staffName using the admin email from staffCredentials
      DocumentSnapshot staffDoc = await FirebaseFirestore.instance
          .collection('staffCredentials')
          .where('email', isEqualTo: adminEmail)
          .limit(1) // Limit to one result
          .get()
          .then((querySnapshot) => querySnapshot.docs.isNotEmpty
              ? querySnapshot.docs.first as DocumentSnapshot<Object?>
              : throw Exception("No staff document found"));

      String staffName =
          staffDoc['staffName']; // Retrieve staffName from staffCredentials

      // Fetch the request document to get the requestType and userName
      DocumentSnapshot requestDoc = await FirebaseFirestore.instance
          .collection('guestRequests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        print("Request document does not exist.");
        return;
      }

      String requestType = requestDoc['requestType'];
      String userName = requestDoc['userName']; // Get the userName of the guest

      // Update the status of the request and set updatedBy to staffName
      await FirebaseFirestore.instance
          .collection('guestRequests')
          .doc(requestId)
          .update({
        'status': status,
        'updatedBy': staffName,
      });

      // Add a notification document
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc('Status of $requestId for $userName')
          .set({
        'tableId': widget.tableId,
        'requestId': requestId,
        'requestType': requestType,
        'status': status,
        'viewed': false,
        'timestamp': FieldValue.serverTimestamp(),
        'userName': userName,
        'sendTo': 'user',
        'updatedBy': staffName,
      });

      // Notify the user of successful update
      Fluttertoast.showToast(
        msg: "Request status updated to $status",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } catch (e) {
      // Show error message if update fails
      print("Error updating request status: $e"); // Debug: Print the error
      Fluttertoast.showToast(
        msg: "Failed to update request status: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  void _showMessagesScreen(String userName, String userEmail) {
    print(
        "Navigating to AdminMessagesScreen with userName: $userName and userEmail: $userEmail");
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminMessagesScreen(
          tableId: widget.tableId,
          userName: userName,
          userEmail: userEmail,
        ),
      ),
    );
  }

  void _confirmMarkAsDone(String requestId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Mark as Done"),
          content:
              const Text("Are you sure you want to mark this request as done?"),
          actions: [
            TextButton(
              child: const Text("Not yet"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text("Done"),
              onPressed: () {
                _markAsDone(requestId);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _markAsDone(String requestId) async {
    try {
      // Fetch the request document to get the current status and requestType
      DocumentSnapshot requestDoc = await FirebaseFirestore.instance
          .collection('guestRequests')
          .doc(requestId)
          .get();

      String tableId = requestDoc['tableId'];
      String requestType = requestDoc['requestType'];
      String userName = requestDoc['userName'];

      // add to guest request
      await FirebaseFirestore.instance
          .collection('guestRequests')
          .doc(requestId)
          .update({
        'status': 'done',
      });

      // add the guest request to the done collection
      await FirebaseFirestore.instance
          .collection('guestRequests')
          .doc(requestId)
          .update({
        'status': 'done',
      });

      // Add a new notification document
      await FirebaseFirestore.instance.collection('notifications').add({
        'tableId': tableId,
        'requestId': requestId,
        'requestType': requestType,
        'status': 'done',
        'viewed': false,
        'timestamp': FieldValue.serverTimestamp(),
        'userName': userName,
        'sendTo': 'user',
      });
      Fluttertoast.showToast(
        msg: "Request marked as done successfully",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Failed to mark request as done: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  void _showDeleteConfirmationDialog() {
    TextEditingController confirmationController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Clear Table Requests"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Type 'CLEAR' to confirm clearing of all requests."),
              const SizedBox(height: 10),
              TextField(
                controller: confirmationController,
                decoration: const InputDecoration(
                  labelText: 'Confirmation',
                  hintText: 'CLEAR',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (confirmationController.text == 'CLEAR') {
                  _deleteAllRequests();
                  Navigator.of(context).pop();
                } else {
                  Fluttertoast.showToast(
                    msg: "Incorrect confirmation text",
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                    timeInSecForIosWeb: 1,
                    backgroundColor: Colors.red,
                    textColor: Colors.white,
                    fontSize: 16.0,
                  );
                }
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(Colors.white),
              ),
              child: const Text("CLEAR"),
            ),
          ],
        );
      },
    );
  }

  void _deleteAllRequests() async {
    var snapshots = await FirebaseFirestore.instance
        .collection('guestRequests')
        .where('tableId', isEqualTo: widget.tableId)
        .get();
    for (var doc in snapshots.docs) {
      await doc.reference.delete();
    }
  }

  Widget _buildRequestList(String status) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('guestRequests')
          .where('tableId', isEqualTo: _selectedTableId)
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No requests for this table"));
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: snapshot.data!.docs.map((doc) {
            var data = doc.data() as Map<String, dynamic>;

            var requestType = doc['requestType'];
            String requestTypeText;
            if (requestType is List) {
              requestTypeText = requestType.join(', ');
            } else {
              requestTypeText = requestType.toString();
            }

            String userName = data['userName'] ?? "Guest";
            String staffName = data['updatedBy'] ?? "Unassigned";
            String remarks = data['remarks'] ?? "No Remarks";
            String itemName;
            if (data['items'] is List) {
              itemName = data['items'].join(', ');
            } else {
              itemName = data['items'].toString();
            }
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    requestTypeText,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (itemName != "null")
                    Text(
                      "Items: $itemName",
                      style: const TextStyle(fontSize: 14),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    "Time of Request: ${DateFormat('MMMM d, y h:mm a').format(data['timestamp'].toDate())}",
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Requested by $userName",
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (doc['status'] == 'rejected') ...[
                    Text(
                      "Rejected by $staffName",
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      "Remarks: $remarks",
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                  if (doc['status'] == 'accepted')
                    Text(
                      "Accepted by $staffName",
                      style: const TextStyle(fontSize: 14),
                    ),
                  if (doc['status'] == 'done')
                    Text(
                      "Done by $staffName",
                      style: const TextStyle(fontSize: 14),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildTrailingButtons(doc['status'], doc.id) ??
                          Container(),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget? _buildTrailingButtons(String status, String requestId) {
    if (status == 'pending') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: () {
              // Handle reject button
              _showRejectDialog(requestId);
              // _updateRequestStatus(requestId, 'rejected');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[300],
            ),
            child: const Text(
              "Reject",
              style: TextStyle(color: Colors.black),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              // Handle accept button
              _updateRequestStatus(requestId, 'accepted');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text(
              "Accept",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      );
    } else if (status == 'accepted') {
      return IconButton(
        icon: const Icon(Icons.checklist, color: Colors.grey),
        onPressed: () {
          _confirmMarkAsDone(requestId);
        },
      );
    } else if (status == 'rejected') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text("Confirm Deletion"),
                    content: const Text(
                        "Are you sure you want to delete this request?"),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close the dialog
                        },
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close the dialog
                          _deleteRequest(
                              requestId); // Perform the delete action
                        },
                        child: const Text("Delete",
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      );
    } else if (status == 'done') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text("Confirm Deletion"),
                    content: const Text(
                        "Are you sure you want to delete this request?"),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close the dialog
                        },
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close the dialog
                          _deleteRequest(
                              requestId); // Perform the delete action
                        },
                        child: const Text("Delete",
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      );
    } else {
      return null;
    }
  }

  void _showRejectDialog(String requestId) {
    final TextEditingController remarksController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Reject Request"),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8, // Set width to 80% of screen width
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start, // Align content to the left
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // Allow the column to take minimum height
                    crossAxisAlignment: CrossAxisAlignment.start, // Align text to the left
                    children: [
                      const Text("Please provide remarks for rejection:"),
                      const SizedBox(height: 8), // Space between text and text field
                      TextField(
                        controller: remarksController,
                        decoration: const InputDecoration(
                          hintText: "Remarks",
                          border: OutlineInputBorder(), 
                        ),
                        maxLines: null, // Allow multiple lines
                        keyboardType: TextInputType.multiline, // Enable multiline keyboard
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                final remarks = remarksController.text;
                if (remarks.isNotEmpty) {
                  _updateRequestStatus(requestId, 'rejected');
                  _updateRequestStatusWithRemarks(requestId, remarks);
                  Navigator.of(context).pop(); // Close the dialog
                } else {
                  // Show a message if remarks are empty
                  Fluttertoast.showToast(
                    msg: "Remarks cannot be empty.",
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                    timeInSecForIosWeb: 1,
                    backgroundColor: Colors.red,
                    textColor: Colors.white,
                    fontSize: 16.0,
                  );
                }
              },
              child: const Text("Reject", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _updateRequestStatusWithRemarks(String requestId, String remarks) {

    FirebaseFirestore.instance.collection('guestRequests').doc(requestId).update({
      'remarks': remarks,
    }).then((_) {
      Fluttertoast.showToast(
        msg: "Request rejected successfully.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }).catchError((error) {
      // Handle error
      Fluttertoast.showToast(
        msg: "Failed to update request: $error.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    });
  }

  Future<void> _deleteRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection('guestRequests')
          .doc(requestId)
          .delete();
      Fluttertoast.showToast(
        msg: "Request deleted successfully",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Failed to delete request: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              {
                    "table_1": "Table 1",
                    "table_2": "Table 2",
                    "table_3": "Table 3",
                    "table_4": "Table 4",
                    "table_5": "Table 5",
                  }[widget.tableId] ??
                  widget.tableId, // Default to tableId if not found in the map
            ),
            TextButton(
              onPressed: _showDeleteConfirmationDialog,
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey,
                backgroundColor: Colors.transparent, // Set icon color to grey
              ),
              child: const Text("CLEAR"),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Pending"),
            Tab(text: "Accepted"),
            Tab(text: "Rejected"),
            Tab(text: "Done")
          ],
        ),
        actions: [
          StreamBuilder(
            stream: FirebaseFirestore.instance
                .collection('adminNotifications')
                .where('viewed', isEqualTo: false)
                .snapshots(),
            builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                return IconButton(
                  icon: Stack(
                    children: [
                      const Icon(Icons.notifications),
                      Positioned(
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 12,
                            minHeight: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminNotificationScreen(),
                      ),
                    );
                  },
                );
              } else {
                return IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminNotificationScreen(),
                      ),
                    );
                  },
                );
              }
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRequestList('pending'),
          _buildRequestList('accepted'),
          _buildRequestList('rejected'),
          _buildRequestList('done'),
        ],
      ),
      floatingActionButton: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.all(30.0), // Adjust the padding as needed
          child: FloatingActionButton(
            onPressed: () => _showMessagesScreen(userName, userEmail),
            backgroundColor: Colors.white,
            child: const Icon(Icons.message),
          ),
        ),
      ),
    );
  }
}
