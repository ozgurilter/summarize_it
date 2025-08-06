import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:summarize_it/model/user.dart';

class SavedSummariesPage extends StatefulWidget {
  final User user;

  const SavedSummariesPage({Key? key, required this.user}) : super(key: key);

  @override
  _SavedSummariesPageState createState() => _SavedSummariesPageState();
}

class _SavedSummariesPageState extends State<SavedSummariesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DateTimeRange? _selectedDateRange;
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.deepPurple,
              onPrimary: Colors.white,
              onSurface: Colors.deepPurple,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.deepPurple,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedDateRange = null;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Kaydedilen Özetler'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined),
            onPressed: () => _selectDateRange(context),
            tooltip: 'Tarih Filtresi',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Özetlerde ara...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchQuery.isNotEmpty || _selectedDateRange != null
                      ? IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _clearFilters,
                  )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),
          ),

          if (_selectedDateRange != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Chip(
                    label: Text(
                      '${DateFormat('dd MMM yyyy').format(_selectedDateRange!.start)} - '
                          '${DateFormat('dd MMM yyyy').format(_selectedDateRange!.end)}',
                    ),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: _clearFilters,
                    backgroundColor: Colors.deepPurple.withOpacity(0.1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getFilteredSummaries(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Veriler yüklenirken hata oluştu',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Tekrar Dene'),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.data?.docs.isEmpty ?? true) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/empty_state.png',
                          width: 200,
                          height: 200,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Kaydedilmiş özet bulunamadı',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_selectedDateRange != null || _searchQuery.isNotEmpty)
                          TextButton(
                            onPressed: _clearFilters,
                            child: const Text('Filtreleri temizle'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.deepPurple,
                            ),
                          ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  color: Colors.deepPurple,
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: snapshot.data!.docs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final timestamp = data['timestamp'] as Timestamp;
                      final date = timestamp.toDate();

                      return _buildSummaryCard(data, date, doc.id);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getFilteredSummaries() {
    Query query = _firestore
        .collection('summaries')
        .where('userEmail', isEqualTo: widget.user.email)
        .orderBy('timestamp', descending: true);

    if (_selectedDateRange != null) {
      query = query
          .where('timestamp', isGreaterThanOrEqualTo: _selectedDateRange!.start)
          .where('timestamp', isLessThanOrEqualTo: _selectedDateRange!.end);
    }

    return query.snapshots();
  }

  Widget _buildSummaryCard(Map<String, dynamic> data, DateTime date, String docId) {
    final summary = data['summary'] as String;
    final url = data['url'] as String;
    final videoTitle = data['videoTitle'] as String? ?? url;
    final highlights = data['highlights'] as String?;

    final matchesSearch = _searchQuery.isEmpty ||
        summary.toLowerCase().contains(_searchQuery) ||
        url.toLowerCase().contains(_searchQuery) ||
        videoTitle.toLowerCase().contains(_searchQuery) ||
        (highlights?.toLowerCase().contains(_searchQuery) ?? false);

            if (!matchesSearch) return const SizedBox.shrink();

    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red[100],
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      confirmDismiss: (direction) async {
        return await _confirmDelete(docId);
      },
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showSummaryDialog(summary, url, date, videoTitle, highlights),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        DateFormat('HH:mm').format(date),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat('dd MMM yyyy').format(date),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  videoTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  summary.length > 120
                      ? '${summary.substring(0, 120)}...'
                      : summary,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                if (highlights != null && highlights.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.highlight_alt, size: 16, color: Colors.orange),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          highlights.split('\n').take(1).first,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.link, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        url,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

  void _showSummaryDialog(String summary, String url, DateTime date, String title, String? highlights) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              DateFormat('dd MMM yyyy, HH:mm').format(date),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.deepPurple,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        child: Text(
                          url,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Özet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        summary,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.6,
                        ),
                      ),
                      if (highlights != null && highlights.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Önemli Noktalar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            highlights,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Kapat'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _confirmDelete(String docId) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.delete_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Özeti Sil',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bu özeti silmek istediğinize emin misiniz?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.deepPurple,
                        side: const BorderSide(color: Colors.deepPurple),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('İptal'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Sil'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('summaries').doc(docId).delete();
        if (!mounted) return true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Özet başarıyla silindi'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            backgroundColor: Colors.green,
          ),
        );
        return true;
      } catch (e) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Silme hatası: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    }
    return false;
  }}