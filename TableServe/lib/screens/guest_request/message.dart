import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MessagesScreen extends StatelessWidget {
  final String tableId;
  final String userName;
  final String userEmail;

  const MessagesScreen({
    required this.tableId,
    required this.userName,
    required this.userEmail,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final TextEditingController messageController = TextEditingController();
    String uniqueUserName = "$userName: $userEmail";

    void sendMessage() async {
      if (messageController.text.isNotEmpty) {
        String docName = 'Guest Message - ${DateTime.now().millisecondsSinceEpoch}';

        // Debugging print statements
        log("Sending message with uniqueUserName: $uniqueUserName" as num);
        log("Message: ${messageController.text}" as num);

        // Save the message to the new 'messages' collection
        await FirebaseFirestore.instance
            .collection('messages')
            .doc(docName)
            .set({
          'tableId': tableId,
          'message': messageController.text,
          'timestamp': FieldValue.serverTimestamp(),
          'sender': 'guest',
          'userName': uniqueUserName,
        });
        messageController.clear();

        // Add a notification document
        await FirebaseFirestore.instance.collection('adminNotifications').add({
          'type': 'newMessage',
          'message': 'New message from user "$uniqueUserName" at table "$tableId" - ${messageController.text}',
          'timestamp': FieldValue.serverTimestamp(),
          'viewed': false,
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Admin"), // Set the title to the user's name
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('messages')
                  .where('tableId', isEqualTo: tableId)
                  .where('userName', isEqualTo: uniqueUserName) // Filter messages by uniqueUserName
                  .orderBy('timestamp', descending: true) // Order messages by timestamp
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  // Log the error for debugging
                  log("Error loading messages: ${snapshot.error}" as num);
                  return const Center(child: Text("Error loading messages"));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No messages"));
                }

                return ListView(
                  reverse: true, // Reverse the order of the messages
                  children: snapshot.data!.docs.map((doc) {
                    var message = doc.data() as Map<String, dynamic>;
                    bool isGuest = message['sender'] == 'guest';
                    Timestamp? timestamp = message['timestamp'] as Timestamp?;
                    return Column(
                      crossAxisAlignment: isGuest
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 5),
                        Align(
                          alignment: isGuest
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                                vertical: 5.0, horizontal: 10.0),
                            padding: const EdgeInsets.all(10.0),
                            decoration: BoxDecoration(
                              color: isGuest ? Colors.blue[100] : Colors.grey[300],
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message['message'] ?? 'No message',
                                  style: TextStyle(
                                    color: isGuest ? Colors.black : Colors.black,
                                  ),
                                ),
                                if (timestamp != null)
                                  Text(
                                    timestamp.toDate().toString(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.black54,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (text) {
                sendMessage();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text("Close"),
                ),
                TextButton(
                  onPressed: () {
                    sendMessage();
                  },
                  child: const Text("Send"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}