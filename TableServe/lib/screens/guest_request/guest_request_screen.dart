import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'custom_request_screen.dart';
import 'notification.dart';
import 'message.dart';
import 'dart:developer';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'faq_screen.dart';
import 'package:fluttertoast/fluttertoast.dart';

class GuestRequestScreen extends StatefulWidget {
  const GuestRequestScreen(
      {super.key,
      required String tableId,
      required String userName,
      required String userEmail});

  @override
  GuestRequestScreenState createState() => GuestRequestScreenState();
}

// Spinner Widget for number input
class SpinnerWidget extends StatelessWidget {
  final String item;
  final int selectedCount;
  final ValueChanged<int> onChanged;

  const SpinnerWidget(
      {super.key,
      required this.item,
      required this.selectedCount,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.remove),
          onPressed: selectedCount > 0
              ? () {
                  if (selectedCount > 0) {
                    onChanged(selectedCount - 1);
                  }
                }
              : null,
        ),
        Text('$selectedCount'),
        IconButton(
          icon: Icon(Icons.add),
          onPressed: selectedCount < 5
              ? () {
                  if (selectedCount < 5) {
                    onChanged(selectedCount + 1);
                  }
                }
              : null,
        ),
      ],
    );
  }
}

class GuestRequestScreenState extends State<GuestRequestScreen>
    with WidgetsBindingObserver {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? qrController;
  bool isScanning = false; // Prevent multiple scans
  String tableId = "";
  String userName = "Guest";
  String userEmail = "";
  String uniqueUserName = "";
  List<bool> selectedItems = List.generate(10, (index) => false);
  List<Map<String, dynamic>> requestHistory = [];
  List<String> requestTypes = [];
  Map<String, String> requestInformation = {};
  List<String> selectedRequestItems = [];
  Map<String, List<String>> selectedRequestItemsMap = {};
  Map<String, int> selectedItemQuantities = {};

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  @override
  void initState() {
    super.initState();
    fetchRequestData();
    uniqueUserName = "$userName: $userEmail";
    _initializeLocalNotifications();
    _listenForNotifications();
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message.data);
    });
    WidgetsBinding.instance.addObserver(this);
    _loadTableId();
    _fetchRequestHistory();
    _checkLoginExpiry();

    Timer.periodic(Duration(seconds: 1), (timer) {
      _checkLoginExpiry();
    });
  }

  void _initializeLocalNotifications() {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  void _checkLoginExpiry() async {
    final prefs = await SharedPreferences.getInstance();
    int? loginTimestamp = prefs.getInt('loginTimestamp');
    if (loginTimestamp != null) {
      int currentTime = DateTime.now().millisecondsSinceEpoch;
      int elapsedTime = currentTime - loginTimestamp;
      int timer = 8 * 60 * 60 * 1000;

      if (elapsedTime >= timer) {
        // Log out the user
        await _exitRequest();
      }
    }
  }

  void _listenForNotifications() {
    FirebaseFirestore.instance
        .collection('notifications')
        .where('tableId', isEqualTo: tableId)
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
    int notificationId = DateTime.now()
        .millisecondsSinceEpoch
        .remainder(100000); // Unique ID based on current time

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Retrieve the tableId from the arguments
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      setState(() {
        tableId = args['tableId'];
        userName = args['userName'];
        userEmail = args['userEmail'];
      });
      _saveTableId(args['tableId'], args['userName'], args['userEmail']);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    qrController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      _saveCurrentState();
    }
  }

  Future<void> _saveCurrentState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tableId', tableId);
    await prefs.setString('userName', userName);
    await prefs.setString('userEmail', userEmail);
  }

  Future<void> _loadTableId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      tableId = prefs.getString('tableId') ?? "";
      userName = prefs.getString('userName') ?? "Guest";
      userEmail = prefs.getString('userEmail') ?? "unknown";
      uniqueUserName = "$userName: $userEmail";
    });
    _fetchRequestHistory();
  }

  Future<void> _saveTableId(String id, String name, String userEmail) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tableId', id);
    await prefs.setString('userName', name);
    await prefs.setString('userEmail', userEmail);
  }

  Future<void> _fetchRequestHistory() async {
    if (tableId.isNotEmpty) {
      User? user = FirebaseAuth.instance.currentUser;
      String finalUserName = user?.displayName ?? user?.email ?? "Guest";
      String userEmail = user?.email ?? "unknown";
      String uniqueUserName = "$finalUserName: $userEmail";

      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('guestRequests')
          .where('tableId', isEqualTo: tableId)
          .where('userName', isEqualTo: uniqueUserName)
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        requestHistory = snapshot.docs.map((doc) {
          var data = doc.data() as Map<String, dynamic>;
          data['docId'] = doc.id; // Include the document ID
          return data;
        }).toList();
      });
    }
  }

  void fetchRequestData() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    // Reference to the collection
    CollectionReference requestListRef = firestore.collection('requestList');

    try {
      QuerySnapshot snapshot = await requestListRef.get();
      // Fetch the data
      List<String> fetchedRequestTypes = [];
      Map<String, String> fetchedRequestInformation = {};

      for (var doc in snapshot.docs) {
        String requestType = doc['type'];
        String information = doc['information'];

        fetchedRequestTypes.add(requestType);
        fetchedRequestInformation[requestType] = information;
      }
      setState(() {
        requestTypes = fetchedRequestTypes;
        requestInformation = fetchedRequestInformation;
      });
    } catch (e) {
      log('Error fetching request data: $e');
    }
  }

  // Function to get information based on request type
  String getRequestInformation(String requestType) {
    return requestInformation[requestType] ?? 'No information available';
  }

  Future<List<String>?> _showRequestDialog(String requestType,
      {required List<String> items,
      required List<String> initialSelectedItems}) async {
    // Initialize the selection state (0 means not selected)
    Map<String, int> selectedItemsMap = {
      for (var item in items) item: 0,
    };

    // Update initial selections if necessary
    for (var item in initialSelectedItems) {
      selectedItemsMap[item] = selectedItemQuantities[item] ??
          0; // Set to saved quantity if available
    }

    return showDialog<List<String>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text('Select Items for $requestType'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: items.map((item) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(item),
                      SpinnerWidget(
                        item: item,
                        selectedCount: selectedItemsMap[item]!,
                        onChanged: (int newCount) {
                          setDialogState(() {
                            selectedItemsMap[item] = newCount;
                          });
                        },
                      ),
                    ],
                  );
                }).toList(),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      child: Text('Done'),
                      onPressed: () {
                        // Collect selected items
                        List<String> selected = [];
                        selectedItemsMap.forEach((item, quantity) {
                          if (quantity > 0) {
                            selected
                                .add(item); // Add only items with quantity > 0
                            selectedItemQuantities[item] =
                                quantity; // Save the quantity
                          }
                          // selected.add(item); // Add only items with quantity > 0
                          // selectedItemQuantities[item] = quantity; // Save the quantity
                        });
                        Navigator.of(context).pop(selected);
                      },
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<String>> _fetchItemsFromFirestore(String requestType) async {
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('requestList')
          .doc(requestType)
          .get();

      List<String> items = List<String>.from(snapshot.data()?['items'] ?? []);
      return items;
    } catch (e) {
      log("Error fetching items: $e");
      return [];
    }
  }

  void _showRequestHistoryDialog() async {
    await _fetchRequestHistory(); // Fetch the latest request history

    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(16.0),
              height: MediaQuery.of(context).size.height * 0.8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Requests',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF316175),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  Expanded(
                    child: StatefulBuilder(
                      builder: (BuildContext context, StateSetter setState) {
                        return requestHistory.isEmpty
                            ? Center(
                                child: Text(
                                  'No Request Found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: requestHistory.length,
                                itemBuilder: (context, index) {
                                  var request = requestHistory[index];
                                  var timestamp =
                                      (request['timestamp'] as Timestamp)
                                          .toDate();
                                  return Card(
                                    margin: EdgeInsets.symmetric(vertical: 8.0),
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: ListTile(
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 10.0,
                                        horizontal: 16.0,
                                      ),
                                      title: Text(
                                        request['requestType'],
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF316175),
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Status: ${request['status']}',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 4.0),
                                          Text(
                                            'Time: ${DateFormat('yyyy-MM-dd – kk:mm').format(timestamp)}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                          if (request['status'] == 'rejected' &&
                                              request.containsKey('remarks'))
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const SizedBox(height: 4.0),
                                                Text(
                                                  'Remarks: ${request['remarks']}',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (request['status'] != 'done' &&
                                              request['status'] != 'accepted' &&
                                              request['status'] != 'canceled')
                                            IconButton(
                                              icon: Icon(Icons.cancel,
                                                  color: Colors.red),
                                              onPressed: () async {
                                                bool? confirmDelete =
                                                    await showDialog<bool>(
                                                  context: context,
                                                  builder:
                                                      (BuildContext context) {
                                                    return AlertDialog(
                                                      title: const Text(
                                                          "Confirm Cancel"),
                                                      content: const Text(
                                                          "Are you sure you want to cancel this request?"),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                      context)
                                                                  .pop(false),
                                                          child:
                                                              const Text("No"),
                                                        ),
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                      context)
                                                                  .pop(true),
                                                          child: const Text(
                                                              "Yes",
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .red)),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );

                                                if (confirmDelete == true) {
                                                  // Update the status and timestamp
                                                  await _updateRequestStatus(
                                                      request['docId'],
                                                      'canceled');

                                                  // Notify the admin
                                                  await FirebaseFirestore
                                                      .instance
                                                      .collection(
                                                          'adminNotifications')
                                                      .add({
                                                    'type': 'requestCanceled',
                                                    'message':
                                                        'Request "${request['requestType']}" from user "${request['userName']}" at table "${request['tableId']}" has been canceled.',
                                                    'timestamp': FieldValue
                                                        .serverTimestamp(),
                                                    'viewed': false,
                                                  });

                                                  await _fetchRequestHistory(); // Refresh the request history
                                                  if (mounted) {
                                                    setState(
                                                        () {}); // Update the state to reflect the changes
                                                  }
                                                  Fluttertoast.showToast(
                                                      msg:
                                                          "Request Cancelled successfully.",
                                                      toastLength:
                                                          Toast.LENGTH_SHORT,
                                                      gravity:
                                                          ToastGravity.BOTTOM,
                                                      timeInSecForIosWeb: 1,
                                                      backgroundColor:
                                                          Colors.green,
                                                      textColor: Colors.white,
                                                      fontSize: 16.0);
                                                }
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                      },
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF316175),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  Future<void> _updateRequestStatus(String docId, String newStatus) async {
    await FirebaseFirestore.instance
        .collection('guestRequests')
        .doc(docId)
        .update({
      'status': newStatus,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _submitRequest() async {
    List<Map<String, dynamic>> selectedRequests = [];

    // Check for valid tableId
    if (tableId.isEmpty) {
      Fluttertoast.showToast(
          msg: "No Table ID available.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0);
      return;
    }

    for (int i = 0; i < selectedItems.length; i++) {
      if (selectedItems[i]) {
        List<String> items = selectedRequestItemsMap[requestTypes[i]] ?? [];
        List<String> formattedItems = [];

        if (items.isEmpty) {
          selectedRequests.add({
            'requestType': requestTypes[i],
            'items': null, // No items selected
          });
        } else {
          for (var item in items) {
            int quantity =
                selectedItemQuantities[item] ?? 1; // Get the selected quantity
            formattedItems.add('$quantity $item'); // Combine quantity and item
          }
          selectedRequests.add({
            'requestType': requestTypes[i],
            'items': formattedItems, // The list of selected items
          });
        }
      }
    }

    // Check if any requests were selected
    if (selectedRequests.isEmpty) {
      Fluttertoast.showToast(
          msg: "Please select at least one request.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0);
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 13),
                child: const CircularProgressIndicator(),
              ),
              const SizedBox(height: 20),
              const Text("Please wait a moment..."),
            ],
          ),
        );
      },
    );

    try {
      // Get the current user
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Fluttertoast.showToast(
            msg: "User not signed in.",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0);
        Navigator.of(context).pop();
        return;
      }

      String finalUserName = user.displayName ?? user.email ?? "Guest";
      String userEmail = user.email ?? "unknown";
      String uniqueUserName = "$finalUserName: $userEmail";

      // Submit each request to Firestore
      for (var request in selectedRequests) {
        String requestType = request['requestType'];
        List<String>? items = request['items'];

        String docName = '$tableId-${DateTime.now().millisecondsSinceEpoch}';

        await FirebaseFirestore.instance
            .collection('guestRequests')
            .doc(docName)
            .set({
          'tableId': tableId,
          'requestType': requestType,
          'items': items,
          'status': 'pending',
          'timestamp': Timestamp.now(),
          'userName': uniqueUserName,
        });

        // Analytics and notifications...
        CollectionReference analyticsRef =
            FirebaseFirestore.instance.collection('analytics');
        String analyticsDocId =
            "$tableId + requestCount + ${DateTime.now().toIso8601String().split('T').first}";
        DocumentReference analyticsDoc = analyticsRef.doc(analyticsDocId);

        await analyticsDoc.set({
          'tableId': tableId,
          'requestCount': FieldValue.increment(1),
          'timestamp': FieldValue.serverTimestamp(), // Add timestamp
        }, SetOptions(merge: true));

        CollectionReference globalAnalyticsRef =
            FirebaseFirestore.instance.collection('globalAnalytics');
        String globalAnalyticsDocId =
            "$requestType + ${DateTime.now().toIso8601String().split('T').first}";
        DocumentReference globalAnalyticsDoc =
            globalAnalyticsRef.doc(globalAnalyticsDocId);

        await globalAnalyticsDoc.set({
          requestType: FieldValue.increment(1),
          'timestamp': FieldValue.serverTimestamp(), // Add timestamp
        }, SetOptions(merge: true));

        await FirebaseFirestore.instance.collection('adminNotifications').add({
          'type': 'newRequest',
          'message':
              'New request "$requestType" from user "$uniqueUserName" at table "$tableId"',
          'timestamp': FieldValue.serverTimestamp(),
          'viewed': false,
        });
      }
      setState(() {
        selectedItems = List.generate(10, (index) => false);
        selectedItemQuantities.clear();
      });

      // Notify the user of successful submission
      Fluttertoast.showToast(
          msg: "Requests submitted successfully.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0);
    } catch (e) {
      // Show error message if submission fails
      Fluttertoast.showToast(
          msg: "Failed to submit request: $e.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0);
    } finally {
      // Dismiss the loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _exitRequest() async {
    if (tableId.isEmpty || userName.isEmpty) {
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Padding(
            padding: const EdgeInsets.only(top: 17.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text("Logging out, please wait..."),
              ],
            ),
          ),
        );
      },
    );
    try {
      // Step 1: Update the activeTables collection
      DocumentReference tableRef =
          FirebaseFirestore.instance.collection('activeTables').doc(tableId);

      // Remove the userName from the array
      await tableRef.update({
        'userNames': FieldValue.arrayRemove([userName]),
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('tableId');
      await prefs.remove('userName');
      await prefs.remove('loginTimestamp');

      // Fetch the updated document to check the userNames array
      DocumentSnapshot updatedDoc = await tableRef.get();
      List<dynamic> userNames = updatedDoc['userNames'] ?? [];

      // If the userNames array is empty, set the status to inactive
      if (userNames.isEmpty) {
        await tableRef.update({
          'status': 'inactive',
        });
      }

      log("Updated document: ${updatedDoc.data()}"); // Debug: Print the updated document

      // Step 2: Delete notifications for the user
      var notificationSnapshots = await FirebaseFirestore.instance
          .collection('notifications')
          .where('tableId', isEqualTo: tableId)
          .where('userName', isEqualTo: userName)
          .get();

      if (notificationSnapshots.docs.isNotEmpty) {
        log("Deleting ${notificationSnapshots.docs.length} notifications for userName: $userName");
        for (var doc in notificationSnapshots.docs) {
          await doc.reference.delete();
          log("Deleted notification: ${doc.id}");
        }
      } else {
        log("No notifications found for userName: $userName");
      }

      // Step 3: Delete messages in the messages collection
      var messageSnapshots = await FirebaseFirestore.instance
          .collection('messages')
          .where('tableId', isEqualTo: tableId)
          .where('userName', isEqualTo: userName)
          .get();

      if (messageSnapshots.docs.isNotEmpty) {
        log("Deleting ${messageSnapshots.docs.length} messages for userName: $userName");
        for (var doc in messageSnapshots.docs) {
          await doc.reference.delete();
          log("Deleted message: ${doc.id}");
        }
      } else {
        log("No messages found for userName: $userName");
      }

      // Step 4: Sign out from Firebase Authentication
      await FirebaseAuth.instance.signOut();

      // Step 5: Notify the user of success
      // ignore: use_build_context_synchronously
      Fluttertoast.showToast(
          msg: "Thank you for using the service.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0);

      // Step 6: Reset state and navigate
      setState(() {
        tableId = "";
        selectedItems = List.generate(10, (index) => false);
      });

      // ignore: use_build_context_synchronously
      Navigator.popAndPushNamed(context, '/qrCode');
    } catch (e) {
      // Handle errors and log
      log("Error: $e");
      // ignore: use_build_context_synchronously
      Fluttertoast.showToast(
          msg: "Failed to update the table status: $e.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0);
    }
  }

  Future<void> _showMessagesScreen() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MessagesScreen(
          tableId: tableId,
          userName: userName,
          userEmail: userEmail,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE4CB9D),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text("TableServe",
                style: TextStyle(
                  color: Color(0xffffffff),
                  fontFamily: "RubikOne",
                )),
          ],
        ),
        leading: IconButton(
          icon: Transform.rotate(
            angle: 3.14, // 180 degrees in radians
            child: const Icon(Icons.logout),
          ),
          onPressed: () async {
            bool? confirmExit = await showDialog<bool>(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text("Confirm Exit"),
                  content: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Are you sure you want to exit?"),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text("Exit",
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                );
              },
            );

            if (confirmExit == true) {
              _exitRequest();
            }
          },
        ),
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FaqScreen(),
                    ),
                  );
                },
                child: const Text(
                  "FAQs",
                  style: TextStyle(
                    color: Color.fromARGB(255, 49, 49, 49),
                    fontSize: 12,
                  ),
                ),
              ),
              StreamBuilder(
                stream: FirebaseFirestore.instance
                    .collection('notifications')
                    .where('tableId', isEqualTo: tableId)
                    .where('userName', isEqualTo: uniqueUserName)
                    .where('viewed',
                        isEqualTo: false) // Only show unviewed notifications
                    .snapshots(),
                builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (snapshot.hasData) {
                    log(uniqueUserName);
                    if (snapshot.data!.docs.isNotEmpty) {
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
                                child: const Text(
                                  '!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                        onPressed: () async {
                          if (tableId.isNotEmpty) {
                            // Update the status of the notifications to 'viewed'
                            var batch = FirebaseFirestore.instance.batch();
                            for (var doc in snapshot.data!.docs) {
                              batch.update(doc.reference, {'viewed': true});
                            }
                            await batch.commit();

                            if (mounted) {
                              Navigator.push(
                                // ignore: use_build_context_synchronously
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NotificationScreen(
                                    tableId: tableId,
                                    userName: userName,
                                    userEmail: userEmail,
                                  ),
                                ),
                              );
                            }
                          } else {
                            Fluttertoast.showToast(
                                msg: "No Table ID available.",
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.BOTTOM,
                                timeInSecForIosWeb: 1,
                                backgroundColor: Colors.red,
                                textColor: Colors.white,
                                fontSize: 16.0);
                          }
                        },
                      );
                    }
                  }
                  return IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () {
                      if (tableId.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NotificationScreen(
                              tableId: tableId,
                              userName: userName,
                              userEmail: userEmail,
                            ),
                          ),
                        );
                      } else {
                        Fluttertoast.showToast(
                            msg: "No Table ID available.",
                            toastLength: Toast.LENGTH_SHORT,
                            gravity: ToastGravity.BOTTOM,
                            timeInSecForIosWeb: 1,
                            backgroundColor: Colors.red,
                            textColor: Colors.white,
                            fontSize: 16.0);
                      }
                    },
                  );
                },
              ),
            ],
          ),
        ],
        centerTitle: true,
        backgroundColor: const Color(0xFFE4CB9D),
        elevation: 0,
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
      body: Stack(children: [
        // Background image that takes the full width and responsive height based on aspect ratio
        Positioned(
          bottom: 0, // Make sure it's at the bottom of the screen
          left: 0,
          right: 0,
          child: Builder(
            builder: (context) {
              // Get the screen width
              double screenWidth = MediaQuery.of(context).size.width;

              // Assuming the image's aspect ratio (width / height) is 16:9 (you can adjust based on your image)
              double aspectRatio = 16 / 9;
              double imageHeight = screenWidth / aspectRatio;

              return Container(
                width: screenWidth,
                height: imageHeight, // Responsive height based on aspect ratio
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(
                        'images/bg.png'), // Replace with your background image path
                    fit: BoxFit
                        .cover, // Ensure it covers the width and scales the height responsively
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Text(
                "Guest Request",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF316175),
                  shadows: [
                    Shadow(
                      offset: Offset(1.0, 1.0),
                      blurRadius: 3.0,
                      color: Colors.black26,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                "Select your request",
                style: TextStyle(fontSize: 16, color: Color(0xFF316175)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),

              // Multi-select Options List
              Expanded(
                child: ListView.builder(
                  itemCount: requestTypes.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () async {
                        List<String> items =
                            await _fetchItemsFromFirestore(requestTypes[index]);
                        // ignore: unrelated_type_equality_checks
                        if (items.isEmpty || items == "null") {
                          setState(() {
                            selectedItems[index] = !selectedItems[index];
                          });
                        } else {
                          List<String> initialSelectedItems =
                              selectedRequestItemsMap[requestTypes[index]] ??
                                  [];
                          List<String>? selectedItems =
                              await _showRequestDialog(
                            requestTypes[index],
                            items: items,
                            initialSelectedItems: initialSelectedItems,
                          );
                          if (selectedItems != null &&
                              selectedItems.isNotEmpty) {
                            setState(() {
                              this.selectedItems[index] = true;
                              selectedRequestItemsMap[requestTypes[index]] =
                                  selectedItems;
                            });
                          } else {
                            setState(() {
                              this.selectedItems[index] = false;
                              selectedRequestItemsMap[requestTypes[index]] = [];
                            });
                          }
                        }
                      },
                      child: Row(
                        children: [
                          Container(
                            height:
                                60, // Set this to match the height of the white box
                            alignment: Alignment.center,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(30),
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () {
                                // Handle information button press
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: Text('Information'),
                                      content: Text(getRequestInformation(
                                          requestTypes[index])),
                                      actions: <Widget>[
                                        TextButton(
                                          child: Text('Close'),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                              child: Icon(
                                Icons.info,
                                size: 50, // Adjust the size as needed
                                color: selectedItems[index]
                                    ? const Color(0xFF316175)
                                    : const Color.fromARGB(255, 255, 255, 255),
                              ),
                            ),
                          ),
                          const SizedBox(
                              width:
                                  10), // Add some space between the button and the container
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 8.0),
                              decoration: BoxDecoration(
                                color: selectedItems[index]
                                    ? const Color(0xFF316175)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(30.0),
                                boxShadow: [
                                  BoxShadow(
                                    // ignore: deprecated_member_use
                                    color: Colors.grey.withOpacity(0.3),
                                    spreadRadius: 1,
                                    blurRadius: 3,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    const SizedBox(
                                        width:
                                            10), // Add some space between the button and the text
                                    Expanded(
                                      child: Text(
                                        requestTypes[
                                            index], // Display request type name
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: selectedItems[index]
                                              ? Colors.white
                                              : const Color.fromARGB(
                                                  255, 49, 97, 117),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Submit Request Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
                  backgroundColor: const Color(0xFF316175),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                ),
                onPressed: _submitRequest, // Call Firestore submission
                child: const Text("Submit Request",
                    style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
              const SizedBox(height: 10),

              // Custom Request Button
              ElevatedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF316175),
                  padding: const EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CustomRequestScreen(
                        tableId: tableId,
                        userName: userName,
                      ),
                    ),
                  );
                },
                child: const Text("Custom Request",
                    style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ]),
      floatingActionButton: Stack(
        children: [
          Align(
            alignment: Alignment.bottomRight,
            child: FloatingActionButton(
              heroTag: 'messageButton',
              onPressed: _showMessagesScreen,
              backgroundColor: const Color.fromARGB(255, 255, 255, 255),
              child: const Icon(Icons.message),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding:
                  const EdgeInsets.only(left: 30.0), // Add margin to the left
              child: FloatingActionButton(
                heroTag: 'historyButton',
                onPressed: _showRequestHistoryDialog,
                backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                child: Icon(Icons.history),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
