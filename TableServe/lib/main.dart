import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/screens/guest_request/faq_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/guest_request/guest_request_screen.dart';
import 'screens/guest_request/custom_request_screen.dart';
import 'screens/qr_code/qr_code_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final tableId = prefs.getString('tableId') ?? "";
  final userName = prefs.getString('userName') ?? "Guest";
  final userEmail = prefs.getString('userEmail') ?? "";

  // Load environment variables and ensure it completes
  await dotenv.load(fileName: "assets/.env");

  // Initialize firebase
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: dotenv.env['apiKey']!,
      appId: dotenv.env['appId']!,
      messagingSenderId: dotenv.env['messagingSenderId']!,
      projectId: dotenv.env['projectId']!,
    ),
  );

  AwesomeNotifications().initialize(
    'resource://drawable/ic_launcher', // Default icon for notifications
    [
      NotificationChannel(
        channelKey: 'high_importance_channel',
        channelName: 'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        defaultColor: Color(0xFF9D50DD),
        ledColor: Colors.white,
        importance: NotificationImportance.High,
      ),
    ],
  );

  // Request notification permissions
  await AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
    if (!isAllowed) {
      AwesomeNotifications().requestPermissionToSendNotifications();
    }
  });

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // runZonedGuarded((){
  //   runApp(const MyApp());
  // },(error, stackTrace){
  //   print("App forcefully closed.");
  //   navigatorKey.currentState?.pop();
  // });
  runApp(MyApp(tableId: tableId, userName: userName, userEmail: userEmail));

}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  AwesomeNotifications().createNotificationFromJsonData(message.data);
}

class MyApp extends StatefulWidget {
  final String tableId;
  final String userName;
  final String userEmail;

  const MyApp({super.key, required this.tableId, required this.userName, required this.userEmail});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    // Listen for connectivity changes.
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      // Update the connection status.
      setState(() {
        _isConnected = result != ConnectivityResult.none;
      });
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TableServe',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Poppins',
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => widget.tableId.isNotEmpty
            ? GuestRequestScreen(tableId: widget.tableId, userName: widget.userName, userEmail: widget.userEmail,)
            : const ScanScreen(),
        '/qrCode': (context) => const ScanScreen(),
        '/guestRequest': (context) => GuestRequestScreen(tableId: widget.tableId, userName: widget.userName, userEmail: widget.userEmail),
        '/customRequest': (context) => CustomRequestScreen(tableId: widget.tableId, userName: widget.userName),
        '/faq': (context) => FaqScreen(),
      },
      builder: (context, child) {
        return Stack(
          children: [
            child!,
            if (!_isConnected)
              Container(
                color: Colors.black54, // Semi-transparent background
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      const SizedBox(height: 20),
                      const Material(
                        color: Colors.transparent,
                        child: Text(
                          'No internet connection. Retrying...',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () {
                          // Exit the app
                          SystemNavigator.pop();
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: const Text(
                          'Exit',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}