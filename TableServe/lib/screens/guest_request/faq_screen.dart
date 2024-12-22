import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  FaqScreenState createState() => FaqScreenState();
}

class FaqScreenState extends State<FaqScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Frequently Asked Questions",
          style: TextStyle(
            fontSize: 16,
            fontFamily: "RubikOne",
            color: Color(0xFF316175),
          ),
        ),
        backgroundColor: const Color(0xFFE4CB9D),
      ),
      body: Container(
        color: const Color(0xFFE4CB9D), // Set background color
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('faqs').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final faqs = snapshot.data!.docs;

            return ListView.builder(
              itemCount: faqs.length,
              itemBuilder: (context, index) {
                var faq = faqs[index];
                var data = faq.data() as Map<String, dynamic>;

                return Container(
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
                      Text(
                        data['title'] ?? 'No Title',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height:8),
                      Text(
                        data['content'] ?? 'No Content',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(data['details'] ?? 'No Details'),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}