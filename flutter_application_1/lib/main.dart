import 'dart:io';

import 'package:flutter/material.dart';
import 'qr_code_generator.dart'; // Import the QR code generator

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Code Generator',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatelessWidget {
  final String tableId = 'table_1';
  final String secretKey = '@tableserve_20+24';

  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Main Screen'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            String? filePath = await saveQRCode(tableId, secretKey);
            if (filePath != null) {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('QR Code Preview'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.file(File(filePath)),
                        SizedBox(height: 20),
                        Text('QR code saved to $filePath'),
                      ],
                    ),
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
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to generate QR code')),
              );
            }
          },
          child: Text('Generate and Save QR Code'),
        ),
      ),
    );
  }
}