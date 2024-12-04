import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationScreen extends StatefulWidget {
  final String tableId;
  final String userName;

  const NotificationScreen(
      {required this.tableId, required this.userName, super.key});

  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  String _selectedStatus = 'all';

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
        .collection('notifications')
        .where('userName', isEqualTo: widget.userName)
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
        title: const Text("Notifications"),
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
              'newMessage'
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

              return ListTile(
                title: Text(data['type'] == 'newMessage'
                    ? "Message from Admin"
                    : "Request: ${data['requestType']}"),
                subtitle: Text(data['type'] == 'newMessage'
                    ? data['message']
                    : "Status: ${data['status']}"),
                onTap: () {
                  print("Notification pressed: $data");
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
        .where('tableId', isEqualTo: widget.tableId)
        .where('userName', isEqualTo: widget.userName);

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
                      .where('userName', isEqualTo: widget.userName)
                      .get();
                  for (var doc in snapshots.docs) {
                    batch.delete(doc.reference);
                  }
                  await batch.commit();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Notifications cleared successfully")),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text("Failed to clear notifications: $e")),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}