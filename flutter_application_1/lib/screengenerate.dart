import 'package:flutter/material.dart';
import 'qr_code_generator.dart'; // Import the QR code generator

class MainScreen extends StatelessWidget {
  final String tableId = 'table_1';
  final String secretKey = 'your_secret_key';

  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Main Screen'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            saveQRCode(tableId, secretKey);
          },
          child: Text('Generate and Save QR Code'),
        ),
      ),
    );
  }
}