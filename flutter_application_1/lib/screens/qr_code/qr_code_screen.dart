import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  ScanScreenState createState() => ScanScreenState();
}

class ScanScreenState extends State<ScanScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  String tableId = ""; // Store the tableId here
  bool isScanning = false; // Prevent multiple scans
  bool isCameraActive = true; // Track camera state

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }


  void _toggleCamera() {
    if (isCameraActive) {
      controller?.pauseCamera();
    } else {
      controller?.resumeCamera();
    }
    setState(() {
      isCameraActive = !isCameraActive;
    });
  }

  @override
  Widget build(BuildContext context) {
    double scanArea =
        MediaQuery.of(context).size.width * 0.75; // 75% of the screen width

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("TableServe"),
          ],
        ),
        elevation: 0,
        // toolbarHeight: 75,
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
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
          ),
        ],
        backgroundColor: Color(0xFFE4CB9D),
      ),
      backgroundColor: Color(0xFFE4CB9D),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Center(
              child: SizedBox(
                child: QRView(
                  key: qrKey,
                  onQRViewCreated: _onQRViewCreated,
                  overlay: QrScannerOverlayShape(
                    borderColor: Color(0xFFE4CB9D),
                    borderRadius: 10,
                    borderLength: 30,
                    borderWidth: 10,
                    cutOutSize: scanArea,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10), // Add some spacing
          IconButton(
            icon: Icon(isCameraActive ? Icons.camera_alt : Icons.videocam_off),
            onPressed: _toggleCamera,
          ),
          const Expanded(
            flex: 1,
            child: Center(
              child: Text(
                'Point the camera at the QR code',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("How to Use the QR Scanner"),
          content: const Text(
            "1. Point the camera at the QR code.\n"
            "2. Ensure the QR code is within the red borders.\n"
            "3. Wait for the scanner to detect the QR code.\n"
            "4. The table ID will be automatically processed.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _promptForName() async {
    TextEditingController nameController = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible:
          false, // Prevent dismissing the dialog by tapping outside
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "Enter Your Username",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          content: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Username',
                hintText: 'Enter your name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  Navigator.of(context).pop(nameController.text);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Name is required")),
                  );
                }
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller;
    });
    // Set up listener for QR code scan
    controller.scannedDataStream.listen((scanData) async {
      if (isScanning) return; // Prevent multiple scans

      setState(() {
        isScanning = true;
      });
       // Turn off the camera
          _toggleCamera();

      try {
        // Get tableId from scanned QR code
        String tableId = scanData.code ?? '';
        print("Scanned QR code: $tableId");

        // Ensure tableId is not empty
        if (tableId.isNotEmpty) {
          String? userName = await _promptForName();
          if (userName == null || userName.isEmpty) {
            userName = "Guest";
          }

          // Add the user to the list of users for the table
          DocumentReference tableRef = FirebaseFirestore.instance
              .collection('activeTables')
              .doc(tableId);
          DocumentSnapshot tableDoc = await tableRef.get();

          if (tableDoc.exists) {
            List<dynamic> userNames = tableDoc['userNames'] ?? [];
            if (userNames.contains(userName)) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'Username "$userName" already exists. Please choose a different name.')),
              );
              if (mounted) {
                setState(() {
                  isScanning = false;
                });
              }
              return;
            } else {
              await tableRef.update({
                'status': 'active',
                'timestamp': Timestamp.now(),
                'userNames': FieldValue.arrayUnion([userName]),
              });
            }
          } else {
            await tableRef.set({
              'status': 'active',
              'timestamp': Timestamp.now(),
              'userNames': [userName],
            });
          }

          // Save tableId and userName to shared preferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('tableId', tableId);
          await prefs.setString('userName', userName);

          // Show confirmation to user
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hello, $userName')),
          );

          // create a new collection of users for analytics
          CollectionReference analyticsRef =
              FirebaseFirestore.instance.collection('analytics');
          DocumentReference analyticsDoc =
              analyticsRef.doc("$tableId + userCount");

          // increment the user count for specific table
          await analyticsDoc.set({
            'tableId': tableId,
            'usersCount': FieldValue.increment(1),
          }, SetOptions(merge: true));

          // notify the admin
          await FirebaseFirestore.instance
              .collection('adminNotifications')
              .add({
            'type': 'newUser',
            'message': 'New user "$userName" added to table "$tableId"',
            'timestamp': FieldValue.serverTimestamp(),
            'viewed': false,
          });

          // Navigate to GuestRequestScreen and pass the tableId and userName
          Navigator.pushReplacementNamed(
            context,
            '/guestRequest',
            arguments: {
              'tableId': tableId,
              'userName': userName
            }, // Pass the tableId and userName here
          );
        } else {
          // Show error if tableId is invalid
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid QR code')),
          );
        }
      } catch (e) {
        print("Error saving to Firebase: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error processing QR code')),
        );
      } finally {
        // Allow scanning again after a delay
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          setState(() {
            isScanning = false;
          });
        }
      }
    });
  }
}
