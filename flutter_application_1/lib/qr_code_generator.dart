import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:crypto/crypto.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';

String generateSecureQRCodeData(String tableId, String secretKey) {
  // Combine the tableId and secretKey
  String dataToHash = '$tableId$secretKey';

  // Generate SHA-256 hash
  var bytes = utf8.encode(dataToHash);
  var digest = sha256.convert(bytes);

  // Combine the unique identifier, tableId, and hash
  return 'TABLESERVE_${tableId}_$digest';
}

Future<String?> saveQRCode(String tableId, String secretKey) async {
  String qrCodeData = generateSecureQRCodeData(tableId, secretKey);

  // Generate QR code
  final qrValidationResult = QrValidator.validate(
    data: qrCodeData,
    version: QrVersions.auto,
    errorCorrectionLevel: QrErrorCorrectLevel.L,
  );

  if (qrValidationResult.status == QrValidationStatus.valid) {
    final qrCode = qrValidationResult.qrCode!;
    final painter = QrPainter.withQr(
      qr: qrCode,
      color: const Color(0xFF000000),
      emptyColor: const Color(0xFFFFFFFF),
      gapless: true,
    );

    // Convert to image
    final image = await painter.toImage(200);
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    // Save to file
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/qr_code.png';
    final file = File(filePath);
    await file.writeAsBytes(buffer);

    print('QR code saved to $filePath');
    return filePath;
  } else {
    print('Failed to generate QR code');
    return null;
  }
}