import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatefulWidget {
  final String tableId;
  final String userName;
  final String userEmail;

  const NotificationScreen({
    required this.tableId,
    required this.userName,
    required this.userEmail,
    super.key,
  });

  @override
  NotificationScreenState createState() => NotificationScreenState();
}

class NotificationScreenState extends State<NotificationScreen> {
  String _selectedStatus = 'all';
  late String uniqueUserName;
  final Set<int> _displayedNotifications = {};

  @override
  void initState() {
    super.initState();
    uniqueUserName = "${widget.userName}: ${widget.userEmail}";
    _listenForNotifications();
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message.data);
    });
  }

  void _listenForNotifications() {
    FirebaseFirestore.instance
        .collection('notifications')
        .where('userName', isEqualTo: uniqueUserName)
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
    if (data['requestType'] == null || data['status'] == null) {
      return;
    }

    int notificationId = data['timestamp'].millisecondsSinceEpoch.remainder(100000); // Unique ID based on timestamp

    if (_displayedNotifications.contains(notificationId)) {
      return; // Notification already displayed
    }

    _displayedNotifications.add(notificationId);

    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: notificationId, // Use unique ID for each notification
        channelKey: 'high_importance_channel',
        title: data['type'] == 'newMessage'
            ? 'Message from Admin'
            : 'Request: ${data['requestType']}',
        body: data['type'] == 'newMessage'
            ? data['message']
            : 'Status: ${data['status']}',
        notificationLayout: NotificationLayout.Default,
        icon: 'resource://drawable/ic_launcher',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications", style: TextStyle(fontSize: 17)),
        actions: [
          DropdownButton<String>(
            value: _selectedStatus,
            icon: const Icon(Icons.filter_list, color: Colors.black),
            dropdownColor: const Color.fromARGB(255, 255, 255, 255),
            onChanged: (String? newValue) {
              setState(() {
                _selectedStatus = newValue!;
              });
            },
            items: <String>[
              'all',
              'accepted',
              'rejected',
              'pending',
              'done',
              'message'
            ].map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(
                  value,
                  style: const TextStyle(color: Colors.black),
                ),
              );
            }).toList(),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              _clearNotifications(context);
            },
          ),
        ],
      ),
      body: StreamBuilder(
        stream: _getNotificationStream(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No notifications"));
          }

          return ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc =
                  snapshot.data!.docs[snapshot.data!.docs.length - 1 - index];
              var data = doc.data() as Map<String, dynamic>;
              bool isViewed = data['viewed'] ?? true;

              return ListTile(
                tileColor: isViewed ? Colors.transparent : Colors.white12, // Highlight if not viewed
                leading: isViewed ? null : Icon(Icons.new_releases, color: Colors.red), // Icon if not viewed
                title: Text(data['type'] == 'newMessage'
                    ? "Message from Admin"
                    : "Request: ${data['requestType']}"),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['type'] == 'newMessage'
                        ? data['message']
                        : "Status: ${data['status']}"),
                    Text(
                      "Time: ${DateFormat('yyyy-MM-dd – kk:mm').format((data['timestamp'] as Timestamp).toDate())}",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                onTap: () async {
                  // Mark the specific notification as viewed
                  await FirebaseFirestore.instance
                      .collection('notifications')
                      .doc(doc.id)
                      .update({'viewed': true});
                },
              );
            },
          );
        },
      ),
    );
  }

  Stream<QuerySnapshot> _getNotificationStream() {
    var query = FirebaseFirestore.instance
        .collection('notifications')
        .orderBy('timestamp', descending: false)
        .where('tableId', isEqualTo: widget.tableId)
        .where('userName', isEqualTo: uniqueUserName);

    if (_selectedStatus != 'all') {
      query = query.where('status', isEqualTo: _selectedStatus);
    }

    return query.snapshots();
  }

  void _clearNotifications(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Clear Notifications"),
          content:
              const Text("Are you sure you want to clear all notifications?"),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text("Clear"),
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  var batch = FirebaseFirestore.instance.batch();
                  var snapshots = await FirebaseFirestore.instance
                      .collection('notifications')
                      .where('tableId', isEqualTo: widget.tableId)
                      .where('userName', isEqualTo: uniqueUserName)
                      .get();
                  for (var doc in snapshots.docs) {
                    batch.delete(doc.reference);
                  }
                  await batch.commit();
                  Fluttertoast.showToast(
                      msg: "Notifications cleared successfully.",
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                      timeInSecForIosWeb: 1,
                      backgroundColor: Colors.green,
                      textColor: Colors.white,
                      fontSize: 16.0);
                } catch (e) {
                  Fluttertoast.showToast(
                      msg: "Failed to clear notifications: $e",
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                      timeInSecForIosWeb: 1,
                      backgroundColor: Colors.red,
                      textColor: Colors.white,
                      fontSize: 16.0);
                }
              },
            ),
          ],
        );
      },
    );
  }
}