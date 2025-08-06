
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:summarize_it/model/user.dart';
import 'dart:convert';
import 'dart:math' as math;

import 'package:summarize_it/quiz_history_page.dart';

class QuizPage extends StatefulWidget {
  final User user;

  const QuizPage({Key? key, required this.user}) : super(key: key);

  @override
  _QuizPageState createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<dynamic> _quizQuestions = [];
  bool _isLoading = false;
  String? _selectedSummaryId;
  String? _selectedSummaryUrl;
  String? _selectedSummaryTitle;
  int _currentQuestionIndex = 0;
  String? _selectedAnswerKey;
  bool _showResult = false;
  int _correctAnswers = 0;
  String? _quizError;
  List<String> _userAnswers = [];

  late AnimationController _progressAnimationController;
  late AnimationController _questionAnimationController;
  late AnimationController _optionAnimationController;
  late AnimationController _confettiController;

  Animation<double>? _progressAnimation;
  Animation<Offset>? _questionSlideAnimation;
  Animation<double>? _questionFadeAnimation;

  static const String _apiBaseUrl = 'http://localhost:8000';

  @override
  void initState() {
    super.initState();
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _questionAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _optionAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _questionSlideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _questionAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _questionFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _questionAnimationController,
      curve: Curves.easeOut,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(colorScheme),
          SliverFillRemaining(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(ColorScheme colorScheme) {
    return SliverAppBar(
      expandedHeight: _selectedSummaryId != null ? 140.0 : 120.0,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          _selectedSummaryId != null ? 'Quiz Zamanı!' : 'Özet Quizleri',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary,
                colorScheme.primary.withOpacity(0.8),
                colorScheme.secondary.withOpacity(0.3),
              ],
            ),
          ),
          child: _selectedSummaryId != null
              ? _buildQuizProgress()
              : _buildQuizIcon(),
        ),
      ),
      actions: [
        if (_selectedSummaryId != null) ...[
          AnimatedScale(
            scale: 1.0,
            duration: const Duration(milliseconds: 200),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _resetQuiz,
              tooltip: 'Quizi Sıfırla',
            ),
          ),
          AnimatedScale(
            scale: 1.0,
            duration: const Duration(milliseconds: 200),
            child: IconButton(
              icon: const Icon(Icons.history_rounded),
              onPressed: _showQuizHistory,
              tooltip: 'Quiz Geçmişi',
            ),
          ),
        ],
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildQuizIcon() {
    return Center(
      child: TweenAnimationBuilder<double>(
        duration: const Duration(seconds: 2),
        tween: Tween(begin: 0, end: 1),
        builder: (context, value, child) {
          return Transform.rotate(
            angle: value * 2 * math.pi * 0.1,
            child: Icon(
              Icons.quiz_rounded,
              size: 48,
              color: Colors.white.withOpacity(0.3),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuizProgress() {
    if (_quizQuestions.isEmpty) return const SizedBox.shrink();

    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Soru ${_currentQuestionIndex + 1}/${_quizQuestions.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Doğru: $_correctAnswers',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _progressAnimationController,
            builder: (context, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (_currentQuestionIndex + 1) / _quizQuestions.length,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 8,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_quizError != null) {
      return _buildErrorView();
    } else if (_selectedSummaryId == null) {
      return _buildSummaryList();
    } else if (_quizQuestions.isEmpty) {
      return _buildQuizLoading();
    } else {
      return _buildQuizView();
    }
  }

  Widget _buildErrorView() {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              tween: Tween(begin: 0, end: 1),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: colorScheme.error,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Bir hata oluştu',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _quizError!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _resetQuiz,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Geri Dön'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('summaries')
          .where('userEmail', isEqualTo: widget.user.email)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        return _buildSummaryGrid(snapshot.data!.docs);
      },
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Özetler yükleniyor...'),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.quiz_outlined,
                size: 64,
                color: colorScheme.primary.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Henüz quiz yok',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Quiz oluşturmak için önce özet kaydetmelisiniz',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryGrid(List<QueryDocumentSnapshot> docs) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.8,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: docs.length,
        itemBuilder: (context, index) {
          final doc = docs[index];
          final data = doc.data() as Map<String, dynamic>;
          final url = data['url'] as String;
          final timestamp = data['timestamp'] as Timestamp;
          final title = data['title'] ?? _extractVideoTitle(url);

          return TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 200 + (index * 100)),
            tween: Tween(begin: 0, end: 1),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: _buildSummaryCard(doc, title, timestamp, index),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(QueryDocumentSnapshot doc, String title, Timestamp timestamp, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final data = doc.data() as Map<String, dynamic>;

    // videoTitle alanını kontrol ediyoruz, yoksa URL'den çıkarılan başlığı kullanıyoruz
    final videoTitle = data['videoTitle'] as String? ?? _extractVideoTitle(data['url'] as String);

    final colors = [
      colorScheme.primaryContainer,
      colorScheme.secondaryContainer,
      colorScheme.tertiaryContainer,
    ];
    final cardColor = colors[index % colors.length];

    return Container(
      decoration: BoxDecoration(
        color: cardColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cardColor.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            final url = data['url'] as String;
            _generateQuiz(doc.id, url, videoTitle); // videoTitle parametresini geçiyoruz
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.quiz_rounded,
                    color: colorScheme.onPrimaryContainer,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        videoTitle, // Düzeltilmiş video başlığını gösteriyoruz
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('dd MMM yyyy').format(timestamp.toDate()),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<int>(
                        future: _getQuizAttemptCount(doc.id),
                        builder: (context, snapshot) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Çözülme: ${snapshot.data ?? 0}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.primary,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildQuizLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            duration: const Duration(seconds: 2),
            tween: Tween(begin: 0, end: 1),
            builder: (context, value, child) {
              return Transform.rotate(
                angle: value * 2 * math.pi,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.psychology_rounded,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            _isLoading ? 'Quiz oluşturuluyor...' : 'Quiz yükleniyor...',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bu işlem birkaç saniye sürebilir',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizView() {
    _questionAnimationController.forward();

    return SlideTransition(
      position: _questionSlideAnimation!,
      child: FadeTransition(
        opacity: _questionFadeAnimation!,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildQuestionCard(),
              ),
            ),
            _buildQuizActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard() {
    final currentQuestion = _quizQuestions[_currentQuestionIndex];
    final options = currentQuestion['options'] as Map<String, dynamic>;
    final explanation = currentQuestion['explanation'] as String;
    final correctAnswer = currentQuestion['correct_answer'] as String;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.help_outline_rounded,
                        color: colorScheme.onPrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedSummaryTitle ?? 'Quiz',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.info_outline_rounded, size: 20),
                      onPressed: _showVideoInfo,
                      tooltip: 'Video Bilgisi',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  currentQuestion['question'],
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                ...options.entries.map((entry) {
                  final optionKey = entry.key;
                  final optionText = entry.value;
                  final isCorrect = optionKey == correctAnswer;
                  final isSelected = _selectedAnswerKey == optionKey;
                  final isUserAnswer = _userAnswers.length > _currentQuestionIndex &&
                      _userAnswers[_currentQuestionIndex] == optionKey;

                  return TweenAnimationBuilder<double>(
                    duration: Duration(milliseconds: 300 + (options.keys.toList().indexOf(optionKey) * 100)),
                    tween: Tween(begin: 0, end: 1),
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(50 * (1 - value), 0),
                        child: Opacity(
                          opacity: value,
                          child: _buildOptionCard(
                            optionKey,
                            optionText,
                            isCorrect,
                            isSelected,
                            isUserAnswer,
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
                if (_showResult) ...[
                  const SizedBox(height: 24),
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 600),
                    tween: Tween(begin: 0, end: 1),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: _buildExplanationCard(explanation),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(String optionKey, String optionText, bool isCorrect, bool isSelected, bool isUserAnswer) {
    final colorScheme = Theme.of(context).colorScheme;

    Color backgroundColor = colorScheme.surface;
    Color borderColor = colorScheme.outline.withOpacity(0.3);
    Color textColor = colorScheme.onSurface;
    IconData? trailingIcon;

    if (_showResult) {
      if (isCorrect) {
        backgroundColor = colorScheme.primaryContainer;
        borderColor = colorScheme.primary;
        trailingIcon = Icons.check_circle_rounded;
      } else if (isUserAnswer && !isCorrect) {
        backgroundColor = colorScheme.errorContainer;
        borderColor = colorScheme.error;
        trailingIcon = Icons.cancel_rounded;
      }
    } else if (isSelected) {
      backgroundColor = colorScheme.primaryContainer.withOpacity(0.5);
      borderColor = colorScheme.primary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: isSelected || (_showResult && (isCorrect || isUserAnswer))
            ? [
          BoxShadow(
            color: borderColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _showResult ? null : () {
            setState(() {
              _selectedAnswerKey = optionKey;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isSelected || (_showResult && isCorrect)
                        ? colorScheme.primary
                        : colorScheme.outline.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      optionKey,
                      style: TextStyle(
                        color: isSelected || (_showResult && isCorrect)
                            ? colorScheme.onPrimary
                            : colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    optionText,
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    trailingIcon,
                    color: isCorrect ? colorScheme.primary : colorScheme.error,
                    size: 24,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExplanationCard(String explanation) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.secondary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.secondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.lightbulb_outline_rounded,
                  color: colorScheme.onSecondary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Açıklama',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            explanation,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizActions() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentQuestionIndex > 0) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _goToPreviousQuestion,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Önceki'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: _showResult ? _buildNextButton() : _buildAnswerButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerButton() {
    return FilledButton.icon(
      onPressed: _selectedAnswerKey == null ? null : _submitAnswer,
      icon: const Icon(Icons.check_rounded),
      label: const Text('Cevapla'),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    final isLastQuestion = _currentQuestionIndex >= _quizQuestions.length - 1;

    return FilledButton.icon(
      onPressed: _goToNextQuestion,
      icon: Icon(isLastQuestion ? Icons.emoji_events_rounded : Icons.arrow_forward_rounded),
      label: Text(isLastQuestion ? 'Sonuçları Göster' : 'Sonraki'),
      style: FilledButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // Quiz işlemleri
  void _submitAnswer() {
    if (_selectedAnswerKey == null) return;

    final currentQuestion = _quizQuestions[_currentQuestionIndex];
    final correctAnswer = currentQuestion['correct_answer'] as String;

    if (_userAnswers.length <= _currentQuestionIndex) {
      _userAnswers.add(_selectedAnswerKey!);
    } else {
      _userAnswers[_currentQuestionIndex] = _selectedAnswerKey!;
    }

    setState(() {
      _showResult = true;
      if (_selectedAnswerKey == correctAnswer) {
        _correctAnswers++;
      }
    });

    // Haptic feedback
    // HapticFeedback.lightImpact();
  }

  void _goToPreviousQuestion() {
    setState(() {
      _currentQuestionIndex--;
      _selectedAnswerKey = _userAnswers.length > _currentQuestionIndex
          ? _userAnswers[_currentQuestionIndex]
          : null;
      _showResult = false;
    });

    _questionAnimationController.reset();
    _questionAnimationController.forward();
  }

  void _goToNextQuestion() {
    if (_currentQuestionIndex < _quizQuestions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswerKey = _userAnswers.length > _currentQuestionIndex
            ? _userAnswers[_currentQuestionIndex]
            : null;
        _showResult = false;
      });

      _questionAnimationController.reset();
      _questionAnimationController.forward();
      _progressAnimationController.forward();
    } else {
      _saveQuizResult();
      _showQuizResults();
    }
  }

  // API ve Database işlemleri
  Future<void> _generateQuiz(String summaryId, String videoUrl, String title) async {
    // Önce summary dokümanını alalım
    final docSnapshot = await _firestore.collection('summaries').doc(summaryId).get();
    final data = docSnapshot.data() as Map<String, dynamic>? ?? {};

    setState(() {
      _selectedSummaryId = summaryId;
      _selectedSummaryUrl = videoUrl;
      _selectedSummaryTitle = data['videoTitle'] as String? ?? title;
      _isLoading = true;
      _quizQuestions = [];
      _currentQuestionIndex = 0;
      _correctAnswers = 0;
      _quizError = null;
      _userAnswers = [];
      _selectedAnswerKey = null;
      _showResult = false;
    });

    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/quiz'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': videoUrl}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        setState(() {
          _quizQuestions = responseData['quiz'];
          _isLoading = false;
        });

        _questionAnimationController.forward();
      } else {
        setState(() {
          _quizError = 'Quiz oluşturulurken hata oluştu (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _quizError = 'Bağlantı hatası: Sunucuya ulaşılamıyor';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveQuizResult() async {
    if (_selectedSummaryId == null) return;

    try {
      await _firestore.collection('quiz_attempts').add({
        'userEmail': widget.user.email,
        'summaryId': _selectedSummaryId,
        'videoUrl': _selectedSummaryUrl,
        'videoTitle': _selectedSummaryTitle,
        'totalQuestions': _quizQuestions.length,
        'correctAnswers': _correctAnswers,
        'score': (_correctAnswers / _quizQuestions.length * 100).round(),
        'userAnswers': _userAnswers,
        'questions': _quizQuestions,
        'timestamp': FieldValue.serverTimestamp(),
        'completedAt': DateTime.now(),
      });
    } catch (e) {
      debugPrint('Quiz sonucu kaydedilemedi: $e');
    }
  }

  Future<int> _getQuizAttemptCount(String summaryId) async {
    try {
      final querySnapshot = await _firestore
          .collection('quiz_attempts')
          .where('summaryId', isEqualTo: summaryId)
          .where('userEmail', isEqualTo: widget.user.email)
          .get();
      return querySnapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  // Utility methods
  String _extractVideoTitle(String url) {
    try {
      final uri = Uri.parse(url);
      final params = uri.queryParameters;
      if (params.containsKey('v')) {
        return 'Video: ${params['v']?.substring(0, 8)}...';
      }
      return 'YouTube Videosu';
    } catch (e) {
      return 'YouTube Videosu';
    }
  }

  String _extractVideoId(String url) {
    try {
      final uri = Uri.parse(url);
      final params = uri.queryParameters;
      return params['v'] ?? 'ID Yok';
    } catch (e) {
      return 'ID Yok';
    }
  }

  // Dialog methods
  void _showVideoInfo() {
    if (_selectedSummaryUrl == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.info_outline_rounded,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Video Bilgisi',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildInfoRow('Başlık', _selectedSummaryTitle ?? 'Bilinmiyor'),
              _buildInfoRow('Video ID', _extractVideoId(_selectedSummaryUrl!)),
              _buildInfoRow('URL', _selectedSummaryUrl!, isUrl: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isUrl = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: isUrl ? Theme.of(context).colorScheme.primary : null,
              ),
              maxLines: isUrl ? 2 : 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showQuizResults() {
    final percentage = (_correctAnswers / _quizQuestions.length * 100).round();
    String message;
    Color color;
    IconData icon;

    if (percentage >= 80) {
      message = 'Harika! Çok başarılı bir performans!';
      color = Colors.green;
      icon = Icons.emoji_events_rounded;
      _confettiController.forward();
    } else if (percentage >= 60) {
      message = 'İyi! Başarılı bir sonuç!';
      color = Colors.orange;
      icon = Icons.thumb_up_rounded;
    } else {
      message = 'Daha iyi yapabilirsin! Tekrar dene!';
      color = Colors.red;
      icon = Icons.refresh_rounded;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween(begin: 0, end: 1),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          size: 48,
                          color: color,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Quiz Tamamlandı!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 1200),
                  tween: Tween(begin: 0, end: _correctAnswers / _quizQuestions.length),
                  builder: (context, value, child) {
                    return Column(
                      children: [
                        Text(
                          '${(value * _quizQuestions.length).round()}/${_quizQuestions.length}',
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('doğru cevap'),
                        const SizedBox(height: 16),
                        Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: value,
                            child: Container(
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Başarı Oranı: $percentage%',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _resetQuiz();
                        },
                        icon: const Icon(Icons.home_rounded),
                        label: const Text('Ana Sayfa'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _retakeQuiz();
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Tekrar Çöz'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _retakeQuiz() {
    setState(() {
      _currentQuestionIndex = 0;
      _correctAnswers = 0;
      _selectedAnswerKey = null;
      _showResult = false;
      _userAnswers = [];
    });

    _questionAnimationController.reset();
    _progressAnimationController.reset();
    _questionAnimationController.forward();
  }

  void _showQuizHistory() {
    if (_selectedSummaryId == null) return;

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => QuizHistoryPage(
          user: widget.user,
          summaryId: _selectedSummaryId!,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeOutCubic)),
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _resetQuiz() {
    setState(() {
      _selectedSummaryId = null;
      _selectedSummaryUrl = null;
      _selectedSummaryTitle = null;
      _quizQuestions = [];
      _currentQuestionIndex = 0;
      _correctAnswers = 0;
      _quizError = null;
      _selectedAnswerKey = null;
      _showResult = false;
      _userAnswers = [];
    });

    _questionAnimationController.reset();
    _progressAnimationController.reset();
  }

  @override
  void dispose() {
    _progressAnimationController.dispose();
    _questionAnimationController.dispose();
    _optionAnimationController.dispose();
    _confettiController.dispose();
    super.dispose();
  }
}