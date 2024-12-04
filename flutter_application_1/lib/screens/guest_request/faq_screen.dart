import 'package:flutter/material.dart';

class faqScreen extends StatefulWidget {
  @override
  faqScreenState createState() => faqScreenState();
}

class faqScreenState extends State<faqScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Frequently Asked Questions",
          style: TextStyle(
            fontSize: 16,
            fontFamily: "RubikOne",
            color: Color(0xFF316175)
          ),
        ),
        backgroundColor: const Color(0xFFE4CB9D),
      ),
      body: Container(
        color: const Color(0xFFE4CB9D), // Set background color
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // General Information Container
            Container(
              padding: const EdgeInsets.all(16.0),
              margin: const EdgeInsets.only(bottom: 16.0),
              decoration: BoxDecoration(
                color: Colors.white, // Set container color to white
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4.0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "General Information",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  const Text("Where is the resort located?", style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text("RH 5 Subic Baraca National Hwy"),
                  const SizedBox(height: 16),
                  const Text("What are the resort's operating hours?", style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text("The resort is open daily from 9 am to 10 pm."),
                  const SizedBox(height: 16),
                  const Text("Is the resort pet-friendly?", style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text("Absolutely!"),
                ],
              ),
            ),

            // Booking and Reservations Container
            Container(
              padding: const EdgeInsets.all(16.0),
              margin: const EdgeInsets.only(bottom: 16.0),
              decoration: BoxDecoration(
                color: Colors.white, // Set container color to white
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4.0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Booking and Reservations",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  const Text("How can I make a reservation?", style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text(
                    "Reservations can be made online through our Facebook page or our contact number 0912351234.",
                  ),
                  const SizedBox(height: 16),
                  const Text("What is your cancellation policy?", style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text(
                    "Cancellations made 48 hours before the scheduled check-in are eligible for a full refund. Late cancellations may incur charges.",
                  ),
                ],
              ),
            ),

            // Facilities and Services Container
            Container(
              padding: const EdgeInsets.all(16.0),
              margin: const EdgeInsets.only(bottom: 16.0),
              decoration: BoxDecoration(
                color: Colors.white, // Set container color to white
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4.0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Facilities and Services",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  const Text("Do you have Wi-Fi?", style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text("Yes, complimentary Wi-Fi is available throughout the resort."),
                  const SizedBox(height: 16),
                  const Text("Is parking available?", style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text("Unfortunately, no."),
                ],
              ),
            ),

            // Policies Container
            Container(
              padding: const EdgeInsets.all(16.0),
              margin: const EdgeInsets.only(bottom: 16.0),
              decoration: BoxDecoration(
                color: Colors.white, // Set container color to white
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4.0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Policies",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  const Text("What are the check-in and check-out times?", style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text("Check-in is at 2:00 PM, and check-out is at 12:00 PM."),
                  const SizedBox(height: 16),
                  const Text("Are there restrictions on beach use?", style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text(
                    "Guests are advised to follow safety guidelines and refrain from swimming after dark.",
                  ),
                  const SizedBox(height: 16),
                  const Text("Do you have a no-smoking policy?", style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text(
                    "Smoking is prohibited in rooms and indoor facilities but is allowed in designated areas.",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
