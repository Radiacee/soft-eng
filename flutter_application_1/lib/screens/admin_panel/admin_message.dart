import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminMessagesScreen extends StatefulWidget {
  final String tableId;
  final String userName;
  final String userEmail;

  const AdminMessagesScreen({
    required this.tableId,
    required this.userName,
    required this.userEmail,
    super.key,
  });

  @override
  AdminMessagesScreenState createState() => AdminMessagesScreenState();
}

class AdminMessagesScreenState extends State<AdminMessagesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, String>> activeUsers = [];
  final TextEditingController messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _fetchActiveUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchActiveUsers() async {
    DocumentSnapshot tableDoc = await FirebaseFirestore.instance
        .collection('activeTables')
        .doc(widget.tableId)
        .get();

    if (tableDoc.exists) {
      if ((tableDoc.data() as Map<String, dynamic>).containsKey('userNames')) {
        Map<String, dynamic> usersMap = tableDoc['userNames'];
        setState(() {
          if (usersMap != null) {
            activeUsers = usersMap.entries.map((entry) {
              String userName = entry.key.trim();
              String userEmail = entry.value.trim();
              print("Extracted userName: $userName, userEmail: $userEmail"); // Debug print
              return {'userName': userName, 'userEmail': userEmail};
            }).toList();
          } else {
            activeUsers = [];
          }
          _tabController = TabController(length: activeUsers.length, vsync: this);
        });
      } else {
        // Handle the case where 'userNames' field does not exist
        setState(() {
          activeUsers = [];
          _tabController = TabController(length: 0, vsync: this);
        });
      }
    } else {
      // Handle the case where the document does not exist
      setState(() {
        activeUsers = [];
        _tabController = TabController(length: 0, vsync: this);
      });
    }
  }

  void sendMessage(String userName, String userEmail) async {
    if (messageController.text.isNotEmpty) {
      String docName =
          'Admin Message - ${DateTime.now().millisecondsSinceEpoch}';

      // Save the message to the new 'messages' collection
      await FirebaseFirestore.instance.collection('messages').doc(docName).set({
        'tableId': widget.tableId,
        'message': messageController.text,
        'timestamp': FieldValue.serverTimestamp(),
        'sender': 'admin',
        'userName': "$userName: $userEmail", // Format userName as "userName: userEmail"
      });

      // Use a unique document ID for each notification
      String notificationId =
          'Notification - ${DateTime.now().millisecondsSinceEpoch}';

      // Add a notification document
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .set({
        'tableId': widget.tableId,
        'userName': "$userName: $userEmail", // Format userName as "userName: userEmail"
        'userEmail': userEmail, // Save the userEmail separately
        'type': 'newMessage',
        'message': messageController.text,
        'timestamp': FieldValue.serverTimestamp(),
        'viewed': false,
      });

      messageController.clear();
      _scrollToBottom(); // Scroll to bottom after sending a message
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Messages"),
        bottom: activeUsers.isNotEmpty
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: activeUsers.map((user) => Tab(text: user['userName'])).toList(),
              )
            : null,
      ),
      body: activeUsers.isNotEmpty
          ? TabBarView(
              controller: _tabController,
              children: activeUsers.map((user) {
                return Column(
                  children: [
                    Expanded(
                      child: StreamBuilder(
                        stream: FirebaseFirestore.instance
                            .collection('messages')
                            .where('tableId', isEqualTo: widget.tableId)
                            .where('userName',
                                isEqualTo: "${user['userName']}: ${user['userEmail']}") // Filter messages by userName in the correct format
                            .orderBy('timestamp', descending: false) // Order messages by timestamp
                            .snapshots(),
                        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            print("Error loading messages: ${snapshot.error}");
                            return const Center(child: Text("Error loading messages"));
                          }
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return const Center(child: Text("No messages"));
                          }

                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_scrollController.hasClients) {
                              _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                            }
                          });

                          return ListView(
                            controller: _scrollController,
                            reverse: false, // Do not reverse the order of the messages
                            children: snapshot.data!.docs.map((doc) {
                              var message = doc.data() as Map<String, dynamic>;
                              bool isAdmin = message['sender'] == 'admin';
                              Timestamp? timestamp = message['timestamp'] as Timestamp?;
                              return Column(
                                crossAxisAlignment: isAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 5),
                                  Align(
                                    alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
                                      padding: const EdgeInsets.all(10.0),
                                      decoration: BoxDecoration(
                                        color: isAdmin ? Colors.blue[100] : Colors.grey[300],
                                        borderRadius: BorderRadius.circular(10.0),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            message['message'],
                                            style: TextStyle(
                                              color: isAdmin ? Colors.black : Colors.black,
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
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: messageController,
                      builder: (context, value, child) {
                        return TextField(
                          controller: messageController,
                          focusNode: _focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Message',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (text) {
                            print("FocusNode has focus: ${_focusNode.hasFocus}");
                          },
                          onTap: () {
                            if (!_focusNode.hasFocus) {
                              _focusNode.requestFocus();
                            }
                          },
                          onSubmitted: (text) {
                            int currentIndex = _tabController.index;
                            String userName = activeUsers[currentIndex]['userName']!;
                            String userEmail = activeUsers[currentIndex]['userEmail']!;
                            sendMessage(userName, userEmail);
                            _focusNode.unfocus();
                          },
                        );
                      },
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
                              int currentIndex = _tabController.index;
                              String userName = activeUsers[currentIndex]['userName']!;
                              String userEmail = activeUsers[currentIndex]['userEmail']!;
                              sendMessage(userName, userEmail);
                              _focusNode.unfocus();
                            },
                            child: const Text("Send"),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            )
          : const Center(child: Text("No users found")),
    );
  }
}