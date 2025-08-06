import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:summarize_it/model/user.dart';

class QuizHistoryPage extends StatelessWidget {
  final User user;
  final String summaryId;

  const QuizHistoryPage({
    Key? key,
    required this.user,
    required this.summaryId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Geçmişi'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('quiz_attempts')
            .where('userEmail', isEqualTo: user.email)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Hata oluştu: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Henüz quiz geçmişi yok'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final score = data['score'] ?? 0;
              final totalQuestions = data['totalQuestions'] ?? 0;
              final correctAnswers = data['correctAnswers'] ?? 0;
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
              final videoTitle = data['videoTitle'] ?? 'Bilinmeyen Video';

              Color scoreColor;
              if (score >= 80) {
                scoreColor = Colors.green;
              } else if (score >= 60) {
                scoreColor = Colors.orange;
              } else {
                scoreColor = Colors.red;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    videoTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        '$correctAnswers/$totalQuestions doğru - %$score',
                        style: TextStyle(
                          color: scoreColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('dd MMM yyyy, HH:mm').format(timestamp),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: CircleAvatar(
                    backgroundColor: scoreColor,
                    child: Text(
                      '$score%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}