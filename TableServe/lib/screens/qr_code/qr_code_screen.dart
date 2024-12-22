import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  ScanScreenState createState() => ScanScreenState();
}

class PasswordVisibilityToggle extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;

  const PasswordVisibilityToggle({
    super.key,
    required this.controller,
    required this.labelText,
  });

  @override
  PasswordVisibilityToggleState createState() =>
      PasswordVisibilityToggleState();
}

class PasswordVisibilityToggleState extends State<PasswordVisibilityToggle> {
  bool _isObscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: widget.labelText,
        prefixIcon: Icon(Icons.vpn_key),
        suffixIcon: IconButton(
          icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility),
          onPressed: () {
            setState(() {
              _isObscure = !_isObscure;
            });
          },
        ),
      ),
      obscureText: _isObscure,
    );
  }
}

class ScanScreenState extends State<ScanScreen> {
  bool isSignUp = false;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  String tableId = ""; // Store the tableId here
  bool isScanning = false; // Prevent multiple scans
  bool isCameraActive = true; // Track camera state

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSignInDialog(tableId);
    });
  }

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

    User? user = FirebaseAuth.instance.currentUser;
    String userName = user?.displayName ?? user?.email ?? "Guest";

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("TableServe"),
          ],
        ),
        elevation: 0,
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
                child: isCameraActive
                    ? QRView(
                        key: qrKey,
                        onQRViewCreated: _onQRViewCreated,
                        overlay: QrScannerOverlayShape(
                          borderColor: Color(0xFFE4CB9D),
                          borderRadius: 10,
                          borderLength: 30,
                          borderWidth: 10,
                          cutOutSize: scanArea,
                        ),
                      )
                    : Center(
                        child: Text(
                          'Turn on the camera to scan a QR code',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (user != null) ...[
            Text(
              'Signed in as $userName',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                setState(() {
                  // Force rebuild to update UI
                });
                _showSignInDialog(tableId);
              },
              child: Text(
                'Remove this account',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
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

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Show dialog to prompt the user to enable location services
      if (mounted) {
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Location Services Disabled'),
              content: Text('Please enable location services to continue.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
      }
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Show dialog to prompt the user to grant location permissions
        if (mounted) {
          await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Location Permission Denied'),
                content: Text('Please grant location permissions to continue.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('OK'),
                  ),
                ],
              );
            },
          );
        }
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Show dialog to inform the user that permissions are permanently denied
      if (mounted) {
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Location Permission Permanently Denied'),
              content: Text(
                  'Location permissions are permanently denied. Please enable them in settings.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
      }
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // When we reach here, permissions are granted and we can continue
    return await Geolocator.getCurrentPosition();
  }

  bool _isLocationWithinRange(Position userLocation, double targetLatitude,
      double targetLongitude, double rangeInMeters) {
    double distance = Geolocator.distanceBetween(
      userLocation.latitude,
      userLocation.longitude,
      targetLatitude,
      targetLongitude,
    );

    return distance <= rangeInMeters;
  }

  Future<void> _forgotPassword() async {
    final TextEditingController resetEmailController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Reset Password'),
          content: SizedBox(
            width:
                MediaQuery.of(context).size.width * 0.8, // 80% of screen width
            child: TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Enter your email',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
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
                final String email = resetEmailController.text.trim();
                if (email.isEmpty) {
                  Fluttertoast.showToast(
                    msg: "Please enter your email address.",
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                    backgroundColor: Colors.red,
                    textColor: Colors.white,
                    fontSize: 16.0,
                  );
                  return;
                }
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      content: Row(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(width: 20),
                          Text("Sending reset link..."),
                        ],
                      ),
                    );
                  },
                );
                try {
                  await FirebaseAuth.instance
                      .sendPasswordResetEmail(email: email);
                  if (mounted) {
                    // ignore: use_build_context_synchronously
                    Navigator.of(context).pop(); // Close the loading dialog
                    // ignore: use_build_context_synchronously
                    Navigator.of(context)
                        .pop(); // Close the reset password dialog
                    Fluttertoast.showToast(
                      msg: "Password reset email sent.",
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                      backgroundColor: Colors.green,
                      textColor: Colors.white,
                      fontSize: 16.0,
                    );
                  }
                } catch (e) {
                  // ignore: use_build_context_synchronously
                  Navigator.of(context).pop(); // Close the loading dialog
                  Fluttertoast.showToast(
                    msg: "Error: ${e.toString()}",
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                    backgroundColor: Colors.red,
                    textColor: Colors.white,
                    fontSize: 16.0,
                  );
                }
              },
              child: Text('Send'),
            ),
          ],
        );
      },
    );
  }

  Future<User?> _signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut(); // Ensure the user is signed out first

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return null; // The user canceled the sign-in
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null &&
          (user.displayName == null || user.displayName!.isEmpty)) {
        // Prompt for the user's name if not already set
        String? userName = await _promptForUserName();
        if (userName != null && userName.isNotEmpty) {
          await user.updateDisplayName(userName);
        }
      }

      return user;
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error signing in with Google: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return null;
    }
  }

  Future<String?> _promptForUserName() async {
    TextEditingController nameController = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("Enter Your Name"),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(nameController.text);
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  Future<User?> _signUpWithEmailAndPassword(
      String email, String password) async {
    try {
      final UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error creating account: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return null;
    }
  }

  Future<User?> _signInWithEmailAndPassword(
      String email, String password) async {
    try {
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = userCredential.user;

      // If the user is signing in (not new), prompt for the name if not set
      if (user != null &&
          (user.displayName == null || user.displayName!.isEmpty)) {
        String? userName = await _promptForUserName();
        if (userName != null && userName.isNotEmpty) {
          await user.updateDisplayName(userName);
        }
      }

      return user;
    } catch (e) {
      if (e is FirebaseAuthException) {
        if (e.code == 'user-not-found') {
          try {
            final UserCredential userCredential =
                await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: email,
              password: password,
            );
            User? user = userCredential.user;

            if (user != null) {
              // Prompt for the user's name
              String? userName = await _promptForUserName();
              if (userName != null && userName.isNotEmpty) {
                await user.updateDisplayName(userName);
              }
            }

            return user;
          } catch (e) {
            Fluttertoast.showToast(
              msg: "Error creating account: $e",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              timeInSecForIosWeb: 1,
              backgroundColor: Colors.red,
              textColor: Colors.white,
              fontSize: 16.0,
            );
            return null;
          }
        } else if (e.code == 'wrong-password') {
          Fluttertoast.showToast(
            msg: "Incorrect password. Please try again.",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0,
          );
        } else if (e.code == 'invalid-email') {
          Fluttertoast.showToast(
            msg: "Invalid email address. Please check and try again.",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0,
          );
        } else {
          Fluttertoast.showToast(
            // msg: "Error: ${e.message}",
            msg: "Error: Please enter correct password.",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0,
          );
        }
      } else {
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
      return null;
    }
  }

  bool isLoading = false;

  void _onQRViewCreated(QRViewController controller,
      [String? userName, String? tableId]) {
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
        // Get tableId from scanned QR code if not provided
        String scannedTableId = tableId ?? scanData.code ?? '';

        Position userLocation = await _getCurrentLocation();
        double targetLatitude = 14.856759; // Replace with your target latitude
        double targetLongitude =
            120.328327; // Replace with your target longitude
        double rangeInMeters = 500; // Define the acceptable range in meters

        if (!_isLocationWithinRange(
            userLocation, targetLatitude, targetLongitude, rangeInMeters)) {
          // Show error if the user's location is not within the acceptable range
          Fluttertoast.showToast(
            msg: "Please use the app at the resort.",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0,
          );
          setState(() {
            isScanning = false;
          });
          _toggleCamera();
          return;
        }

        // Ensure tableId is not empty
        if (scannedTableId.isNotEmpty) {
          User? user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            // Prompt the user to sign in
            user = await _showSignInDialog(scannedTableId);
            if (user == null) {
              setState(() {
                isScanning = false;
              });
              _toggleCamera();
              return;
            }
          }

          String finalUserName = userName ?? user.displayName ?? "Guest";
          String userEmail = user.email ?? "unknown";
          String uniqueUserName = finalUserName;

          if (mounted) {
            // Show loading dialog
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
                        Text("Logging in, please wait..."),
                      ],
                    ),
                  ),
                );
              },
            );
          }

          // Add the user to the list of users for the table
          DocumentReference tableRef = FirebaseFirestore.instance
              .collection('activeTables')
              .doc(scannedTableId);
          DocumentSnapshot tableDoc = await tableRef.get();

          Map<String, dynamic> userNamesMap = {};
          if (tableDoc.exists) {
            var userNames = tableDoc['userNames'];
            if (userNames is List) {
              // Convert list to map
              for (var name in userNames) {
                userNamesMap[name] = '';
              }
            } else if (userNames is Map) {
              userNamesMap = Map<String, dynamic>.from(userNames);
            }
          }

          userNamesMap[uniqueUserName] = userEmail;
          await tableRef.set({
            'status': 'active',
            'timestamp': Timestamp.now(),
            'userNames': userNamesMap,
          }, SetOptions(merge: true));

          // Save tableId and userName to shared preferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('tableId', scannedTableId);
          await prefs.setString('userName', finalUserName);
          await prefs.setString('userEmail', userEmail);
          await prefs.setInt(
              'loginTimestamp', DateTime.now().millisecondsSinceEpoch);

          // Show confirmation to user
          Fluttertoast.showToast(
            msg: "Hello, $finalUserName.",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.green,
            textColor: Colors.white,
            fontSize: 16.0,
          );

          // Create a new collection of users for analytics
          CollectionReference analyticsRef =
              FirebaseFirestore.instance.collection('analytics');
          DocumentReference analyticsDoc = analyticsRef.doc(
              "$scannedTableId + userCount + ${DateTime.now().toIso8601String().split('T').first}");

          // Increment the user count for specific table
          await analyticsDoc.set({
            'tableId': scannedTableId,
            'usersCount': FieldValue.increment(1),
            'timestamp': FieldValue.serverTimestamp(), // Add timestamp
          }, SetOptions(merge: true));

          await FirebaseFirestore.instance.collection('adminAnalytics').add({
            'tableId': scannedTableId,
            'userNames': {
              uniqueUserName: DateFormat('yyyy-MM-dd').format(DateTime.now())
            },
            'timestamp': FieldValue.serverTimestamp(),
          });

          await FirebaseFirestore.instance
              .collection('adminNotifications')
              .add({
            'type': 'newUser',
            'message': 'New user "$finalUserName" added at "$scannedTableId"',
            'timestamp': FieldValue.serverTimestamp(),
            'viewed': false,
          });

          // Navigate to GuestRequestScreen and pass the tableId and userName
          if (mounted) {
            Navigator.pushReplacementNamed(
              context,
              '/guestRequest',
              arguments: {
                'tableId': scannedTableId,
                'userName': finalUserName,
                'userEmail': userEmail,
              }, // Pass the tableId and userName here
            );
          }
        } else {
          // Show error if tableId is invalid
          Fluttertoast.showToast(
            msg: "Invalid QR Code.",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0,
          );
        }
      } catch (e) {
        Fluttertoast.showToast(
          msg: "Error processing QR Code: $e",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
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

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  _showSignInDialog(String scannedTableId) {
    _toggleCamera();
    setState(() {
      isLoading = false; // Reset isLoading state
    });
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Stack(
          children: [
            Positioned(
              bottom: 0, // Make sure it's at the bottom of the screen
              left: 0,
              right: 0,
              child: Builder(
                builder: (context) {
                  double screenWidth = MediaQuery.of(context).size.width;
                  double aspectRatio = 16 / 9;
                  double imageHeight = screenWidth / aspectRatio;

                  return SizedBox(
                    width: screenWidth,
                    height: imageHeight,
                    child: Opacity(
                      opacity: 0.4, // 50% opacity
                      child: Image.asset(
                        'images/bg.png', // Replace with your background image path
                        fit: BoxFit
                            .cover, // Ensure it covers the width and scales the height responsively
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              children: [
                                Image.asset(
                                  'images/logo.png',
                                  height: 100,
                                  width: 100,
                                ),
                                Text(
                                  isSignUp ? 'Get Started' : 'Welcome Back',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: const Color.fromARGB(255, 50, 59,
                                        50), // Text color to ensure visibility
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  isSignUp
                                      ? 'Hello! Welcome to TableServe.'
                                      : 'Hey! It\'s good to see you again.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: const Color.fromARGB(255, 100, 100,
                                        100), // Lighter grey for better visibility
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 50),
                            if (isLoading)
                              CircularProgressIndicator()
                            else ...[
                              TextField(
                                controller: emailController,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.email),
                                ),
                              ),
                              PasswordVisibilityToggle(
                                controller: passwordController,
                                labelText: 'Password',
                              ),
                              if (isSignUp)
                                PasswordVisibilityToggle(
                                  controller: confirmPasswordController,
                                  labelText: 'Confirm Password',
                                ),
                              // Add the Forgot Password Button here
                              if (!isSignUp)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _forgotPassword,
                                    child: Text("Forgot password?"),
                                  ),
                                ),
                              SizedBox(height: 25),
                              ElevatedButton(
                                onPressed: () async {
                                  setState(() {
                                    isLoading = true;
                                  });
                                  final email = emailController.text;
                                  final password = passwordController.text;
                                  final confirmPassword =
                                      confirmPasswordController.text.trim();

                                  User? user;
                                  if (isSignUp) {
                                    if (password != confirmPassword) {
                                      setState(() {
                                        isLoading = false;
                                      });
                                      Fluttertoast.showToast(
                                        msg: "Passwords do not match.",
                                        toastLength: Toast.LENGTH_SHORT,
                                        gravity: ToastGravity.BOTTOM,
                                        timeInSecForIosWeb: 1,
                                        backgroundColor: Colors.red,
                                        textColor: Colors.white,
                                        fontSize: 16.0,
                                      );
                                      return;
                                    }
                                    user = await _signUpWithEmailAndPassword(
                                        email, password);
                                    if (user != null) {
                                      Fluttertoast.showToast(
                                        msg:
                                            "Sign up successful! Please sign in.",
                                        toastLength: Toast.LENGTH_SHORT,
                                        gravity: ToastGravity.BOTTOM,
                                        timeInSecForIosWeb: 1,
                                        backgroundColor: Colors.green,
                                        textColor: Colors.white,
                                        fontSize: 16.0,
                                      );
                                      setState(() {
                                        isSignUp = false;
                                        isLoading = false;
                                      });
                                    } else {
                                      setState(() {
                                        isLoading = false;
                                      });
                                    }
                                  } else {
                                    user = await _signInWithEmailAndPassword(
                                        email, password);
                                    if (user != null) {
                                      String userName = user.displayName ??
                                          user.email ??
                                          "Guest";
                                      // ignore: use_build_context_synchronously
                                      Navigator.of(context).pop(user);
                                      _onQRViewCreated(controller!, userName,
                                          scannedTableId);
                                    } else {
                                      setState(() {
                                        isLoading = false;
                                      });
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor:
                                      Colors.teal, // Teal color for the button
                                  minimumSize: Size(double.infinity, 50),
                                ),
                                child: Text(isSignUp ? 'Sign Up' : 'Sign In'),
                              ),

                              SizedBox(height: 25),
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      thickness: 1,
                                      color:
                                          const Color.fromARGB(255, 75, 75, 75),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10.0),
                                    child: Text(
                                      'Or',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: const Color.fromARGB(
                                            255, 75, 75, 75),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      thickness: 1,
                                      color:
                                          const Color.fromARGB(255, 75, 75, 75),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 25),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  setState(() {
                                    isLoading = true;
                                  });
                                  User? user = await _signInWithGoogle();
                                  if (user != null) {
                                    String userName = user.displayName ??
                                        user.email ??
                                        "Guest";
                                    // ignore: use_build_context_synchronously
                                    Navigator.of(context).pop(user);
                                    _onQRViewCreated(
                                        controller!, userName, scannedTableId);
                                  } else {
                                    setState(() {
                                      isLoading = false;
                                    });
                                  }
                                },
                                icon: Image.asset(
                                  'images/google_logo.png',
                                  height: 24.0,
                                  width: 24.0,
                                ),
                                label: Text('Sign in with Google'),
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.black,
                                  backgroundColor: Colors.white,
                                  minimumSize: Size(double.infinity, 50),
                                ),
                              ),
                              SizedBox(height: 50),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    isSignUp = !isSignUp;
                                  });
                                },
                                child: Text(
                                  isSignUp
                                      ? 'Already a user? Sign in here'
                                      : 'New user? Sign up here',
                                  style: TextStyle(color: Colors.blue),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
