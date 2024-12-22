import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/screens/guest_request/guest_request_screen.dart';
import 'package:fluttertoast/fluttertoast.dart';

class CustomRequestScreen extends StatefulWidget {
  final String tableId;
  final String userName;
  const CustomRequestScreen(
      {super.key, required this.tableId, required this.userName});

  @override
  CustomRequestScreenState createState() => CustomRequestScreenState();
}

class CustomRequestScreenState extends State<CustomRequestScreen> {
  final TextEditingController customRequestController = TextEditingController();

  Future<void> _submitCustomRequest() async {
    String customRequestDetails = customRequestController.text.trim();

    if (customRequestDetails.isEmpty) {
      Fluttertoast.showToast(
          msg: "Please type your custom request.",
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
              const CircularProgressIndicator(),
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

      // Generate a custom document ID using the table ID and timestamp
      String docName =
          '${widget.tableId}-${DateTime.now().millisecondsSinceEpoch}';

      // Save the custom request to Firestore
      await FirebaseFirestore.instance
          .collection('guestRequests')
          .doc(docName)
          .set({
        'tableId': widget.tableId,
        'requestType': customRequestDetails,
        'status': 'pending', // Set status to 'pending'
        'timestamp': Timestamp.now(),
        'userName': uniqueUserName,
      });

      // Add a notification document
      await FirebaseFirestore.instance.collection('adminNotifications').add({
        'type': 'newRequest',
        'message':
            'New request "$customRequestDetails" from user "$uniqueUserName" at table "${widget.tableId}"',
        'timestamp': FieldValue.serverTimestamp(),
        'viewed': false,
      });

      CollectionReference analyticsRef =
          FirebaseFirestore.instance.collection('analytics');
      String analyticsDocId =
          "${widget.tableId} + requestCount + ${DateTime.now().toIso8601String().split('T').first}";
      DocumentReference analyticsDoc = analyticsRef.doc(analyticsDocId);

      await analyticsDoc.set({
        'tableId': widget.tableId,
        'requestCount': FieldValue.increment(1),
        'timestamp': FieldValue.serverTimestamp(), // Add timestamp
      }, SetOptions(merge: true));

      CollectionReference globalAnalyticsRef =
          FirebaseFirestore.instance.collection('globalAnalytics');

      // Include the current date in the document ID
      String globalAnalyticsDocId =
          "Custom Request + ${DateTime.now().toIso8601String().split('T').first}";
      DocumentReference globalAnalyticsDoc =
          globalAnalyticsRef.doc(globalAnalyticsDocId);

      await globalAnalyticsDoc.set({
        "Custom Request": FieldValue.increment(1),
        'timestamp': FieldValue.serverTimestamp(), // Add timestamp
      }, SetOptions(merge: true));

      // Notify the user of successful submission
      Fluttertoast.showToast(
          msg: "Custom request submitted successfully.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0);

      // Clear the text field after submission
      customRequestController.clear();

      // Navigate to the GuestRequestScreen after submission
      if (mounted) {
        // Navigate to the GuestRequestScreen after submission
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => GuestRequestScreen(
              tableId: widget.tableId,
              userName: uniqueUserName,
              userEmail: userEmail,
            ),
          ),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
          msg: "Failed to submit request: $e.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0);
    } finally {
      // Dismiss the loading dialog if it is still visible
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE4CB9D),
      appBar: AppBar(
        title: const Text(
          "TableServe",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
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
      body: Stack(
        children: [
          // Background image that takes the full width and responsive height based on aspect ratio
          Positioned(
            bottom: 0, // Make sure it's at the top of the screen
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
                  height:
                      imageHeight, // Responsive height based on aspect ratio
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
                  "How can we help you?",
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
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  "Describe your service request in detail.",
                  style: TextStyle(fontSize: 16, color: Color(0xFF316175)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Text Input Field
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: TextField(
                    controller: customRequestController,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      hintText: "Type here...",
                      border: InputBorder.none,
                    ),
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
                  onPressed: _submitCustomRequest,
                  child: const Text("Submit Request",
                      style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
