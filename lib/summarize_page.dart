
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:open_filex/open_filex.dart';
import 'package:summarize_it/model/user.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:universal_html/html.dart' as html;

class SummarizePage extends StatefulWidget {
  final User? user;

  const SummarizePage({Key? key, this.user}) : super(key: key);

  @override
  State<SummarizePage> createState() => _SummarizePageState();
}

class _SummarizePageState extends State<SummarizePage>
    with TickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  String? _summary;
  String? _highlights;
  String? _currentUrl;
  bool _isExpanded = false;
  bool _isHighlightsExpanded = false;
  late AnimationController _rotationController;
  late AnimationController _expandController;
  late AnimationController _highlightsExpandController;
  bool _isGeneratingNotes = false;
  String? _lectureNotes;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _highlightsExpandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  String? _videoTitle;

  Future<void> summarize() async {
    if (_urlController.text.trim().isEmpty) {
      _showSnackBar("Lütfen bir YouTube linki girin", Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
      _summary = null;
      _highlights = null;
      _videoTitle = null;
      _isExpanded = false;
      _isHighlightsExpanded = false;
    });

    _expandController.reset();
    _highlightsExpandController.reset();
    _rotationController.repeat();

    try {
      // Özet ve başlık için istek
      final summarizeUri = Uri.parse('http://localhost:8000/summarize');
      final summarizeResponse = await http.post(
        summarizeUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"url": _urlController.text.trim()}),
      );

      // Highlights için istek
      final highlightsUri = Uri.parse('http://localhost:8000/highlights');
      final highlightsResponse = await http.post(
        highlightsUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"url": _urlController.text.trim()}),
      );

      if (summarizeResponse.statusCode == 200 && highlightsResponse.statusCode == 200) {
        final summarizeResult = jsonDecode(summarizeResponse.body);
        final highlightsResult = jsonDecode(highlightsResponse.body);

        setState(() {
          _summary = summarizeResult['summary'];
          _highlights = highlightsResult['highlights'];
          _videoTitle = summarizeResult['title'];
          _currentUrl = _urlController.text.trim();
        });
        _showSnackBar("Özet ve önemli noktalar başarıyla oluşturuldu!", Colors.green);
      } else {
        _showSnackBar("Hata oluştu: ${summarizeResponse.statusCode}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Bağlantı hatası: $e", Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
      _rotationController.stop();
    }
  }

  Future<void> saveSummary() async {
    if (_summary == null || widget.user == null) return;

    try {
      await FirebaseFirestore.instance.collection('summaries').add({
        'userEmail': widget.user!.email,
        'userName': widget.user!.nameSurname,
        'url': _currentUrl,
        'videoTitle': _videoTitle,
        'summary': _summary,
        'highlights': _highlights,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _showSnackBar("Özet başarıyla kaydedildi!", Colors.green);
    } catch (e) {
      _showSnackBar("Kaydetme hatası: $e", Colors.red);
    }
  }

  Future<void> improveSummary(String feedbackType) async {
    if (_summary == null) return;

    setState(() {
      _isLoading = true;
    });

    _rotationController.repeat();

    try {
      final uri = Uri.parse('http://localhost:8000/improve_summary');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "summary": _summary,
          "feedback_type": feedbackType
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        setState(() {
          _summary = result['improved_summary'];
        });
        _showSnackBar("Özet geliştirildi!", Colors.green);
      } else {
        _showSnackBar("Geliştirme hatası: ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Bağlantı hatası: $e", Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
      _rotationController.stop();
    }
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    _isExpanded ? _expandController.forward() : _expandController.reverse();
  }

  void _toggleHighlightsExpansion() {
    setState(() {
      _isHighlightsExpanded = !_isHighlightsExpanded;
    });
    _isHighlightsExpanded
        ? _highlightsExpandController.forward()
        : _highlightsExpandController.reverse();
  }

  void _showFullScreenSummary() {
    if (_summary == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenSummaryPage(
          summary: _summary!,
          highlights: _highlights,
          videoTitle: _videoTitle,
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
  }
  void _showImprovementOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Özeti Nasıl Geliştirmek İstersiniz?",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildImprovementButton(
              "Daha Ayrıntılı",
              "detailed",
              Icons.zoom_in,
              Colors.blue,
            ),
            const SizedBox(height: 10),
            _buildImprovementButton(
              "Daha Kısa",
              "concise",
              Icons.compress,
              Colors.orange,
            ),
            const SizedBox(height: 10),
            _buildImprovementButton(
              "Ana Noktalara Odaklan",
              "key_points",
              Icons.star,
              Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImprovementButton(
      String title,
      String type,
      IconData icon,
      Color color,
      ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pop(context);
          improveSummary(type);
        },
        icon: Icon(icon, color: Colors.white),
        label: Text(
          title,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _rotationController.dispose();
    _expandController.dispose();
    _highlightsExpandController.dispose();
    super.dispose();
  }


  Future<void> generateLectureNotes() async {
    if (_urlController.text.trim().isEmpty) {
      _showSnackBar("Lütfen bir YouTube linki girin", Colors.red);
      return;
    }

    setState(() {
      _isGeneratingNotes = true;
      _lectureNotes = null;
    });

    try {
      final uri = Uri.parse('http://localhost:8000/lecture_notes');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"url": _urlController.text.trim()}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        setState(() {
          _lectureNotes = result['lecture_notes'];
        });
        _showSnackBar("Ders notları oluşturuldu!", Colors.green);
        _showSaveNotesDialog();
      } else {
        _showSnackBar("Hata oluştu: ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Bağlantı hatası: $e", Colors.red);
    } finally {
      setState(() {
        _isGeneratingNotes = false;
      });
    }
  }

  Future<void> _showSaveNotesDialog() async {
    if (_lectureNotes == null) return;

    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        elevation: 10,
        title: Column(
          children: [
            Icon(Icons.note_alt_rounded,
                size: 40,
                color: Colors.deepPurple),
            const SizedBox(height: 8),
            Text("Ders Notları Hazır!",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
        content: Text("Oluşturduğunuz ders notlarını PDF olarak kaydetmek ister misiniz?",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
            )),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text("Daha Sonra",
                      style: GoogleFonts.poppins(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      )),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.save_rounded, size: 20 , color: Colors.white,),
                      const SizedBox(width: 6),
                      Text("PDF Olarak Kaydet",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (save == true) {
      await _saveNotesAsPdf();
    }
  }

  Future<void> _saveNotesAsPdf() async {
    try {
      final pdf = pw.Document();

      // Create a custom style for the PDF text
      final textStyle = pw.TextStyle(
        fontSize: 12,
        lineSpacing: 5,
      );

      // Split the lecture notes into chunks to handle large content

      final asciiText = convertToAscii(_lectureNotes!);
      final chunks = _splitTextIntoChunks(asciiText, 1500);

      for (var i = 0; i < chunks.length; i++) {
        pdf.addPage(
          pw.Page(
            margin: pw.EdgeInsets.all(20),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (i == 0) ...[
                    pw.Text(
                      convertToAscii(_videoTitle ?? 'Ders Notları'),
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Divider(),
                    pw.SizedBox(height: 20),
                  ],
                  pw.Text(
                    chunks[i],
                    style: textStyle,
                  ),
                  if (i == chunks.length - 1) ...[
                    pw.Spacer(),
                    pw.Divider(),
                    pw.Text(
                      'Sayfa ${i + 1}/${chunks.length}',
                      style: pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ],
              );
            },
          ),
        );
      }

      final bytes = await pdf.save();

      // Platform-specific saving logic
      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download = '${_videoTitle ?? 'Ders_Notlari'}_${DateTime.now().millisecondsSinceEpoch}.pdf';

        html.document.body?.children.add(anchor);
        anchor.click();

        // Cleanup
        Future.delayed(Duration(seconds: 1), () {
          html.Url.revokeObjectUrl(url);
          html.document.body?.children.remove(anchor);
        });
      } else {
        final outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'PDF Olarak Kaydet',
          fileName: '${_videoTitle ?? 'Ders_Notlari'}_${DateTime.now().millisecondsSinceEpoch}.pdf',
          allowedExtensions: ['pdf'],
          type: FileType.custom,
        );

        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsBytes(bytes);
          _showSnackBar("PDF başarıyla kaydedildi!", Colors.green);
          await OpenFilex.open(file.path);
        }
      }
    } catch (e) {
      _showSnackBar("PDF kaydedilirken hata oluştu: $e", Colors.red);
    }
  }


  String convertToAscii(String input) {
    final replacements = {
      'ç': 'c', 'Ç': 'C',
      'ğ': 'g', 'Ğ': 'G',
      'ö': 'o', 'Ö': 'O',
      'ş': 's', 'Ş': 'S',
      'ü': 'u', 'Ü': 'U',
      'ı': 'i', 'İ': 'I',
    };

    return input.split('').map((char) => replacements[char] ?? char).join();
  }


  List<String> _splitTextIntoChunks(String text, int chunkSize) {
    final chunks = <String>[];
    for (var i = 0; i < text.length; i += chunkSize) {
      chunks.add(text.substring(
        i,
        i + chunkSize > text.length ? text.length : i + chunkSize,
      ));
    }
    return chunks;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Hoş Geldiniz, ${widget.user?.nameSurname.split(' ').first}'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple, Colors.deepPurple.shade300],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.summarize,
                      size: 40,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Video Özeti Oluştur",
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      "YouTube videolarınızı anlık olarak özetleyin",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // URL Input
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  controller: _urlController,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    labelText: 'YouTube Video Linki',
                    labelStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(Icons.link, color: Colors.deepPurple),
                    suffixIcon: _urlController.text.isNotEmpty
                        ? IconButton(
                      onPressed: () {
                        _urlController.clear();
                        setState(() {});
                      },
                      icon: Icon(Icons.clear, color: Colors.grey),
                    )
                        : null,
                  ),
                  onChanged: (value) => setState(() {}),
                ),
              ),

              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : summarize,
                  icon: _isLoading
                      ? Container(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Icon(Icons.send, color: Colors.white),
                  label: Text(
                    _isLoading ? "Özet Çıkarılıyor..." : "Özet Oluştur",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 0,
                  ),
                ),
              ),

              // Loading Animation
              if (_isLoading && _summary == null) ...[
                const SizedBox(height: 40),
                Center(
                  child: Column(
                    children: [
                      AnimatedBuilder(
                        animation: _rotationController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _rotationController.value * 2 * 3.14159,
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.deepPurple,
                                    Colors.purple.shade200
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.autorenew,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Video analiz ediliyor...",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Summary Result
              if (_summary != null) ...[
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        spreadRadius: 1,
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      )],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      if (_videoTitle != null) ...[
                        Text(
                          _videoTitle!,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.deepPurple,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 15),
                      ],


                      _buildExpandableSection(
                        title: "Özet",
                        icon: Icons.description,
                        content: _summary!,
                        isExpanded: _isExpanded,
                        toggleExpansion: _toggleExpansion,
                        expandController: _expandController,
                      ),

                      const SizedBox(height: 20),


                      if (_highlights != null && _highlights!.isNotEmpty) ...[
                        _buildExpandableSection(
                          title: "Önemli Noktalar",
                          icon: Icons.highlight,
                          content: _highlights!,
                          isExpanded: _isHighlightsExpanded,
                          toggleExpansion: _toggleHighlightsExpansion,
                          expandController: _highlightsExpandController,
                        ),
                        const SizedBox(height: 20),
                      ],


                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: saveSummary,
                              icon: Icon(Icons.save, size: 18),
                              label: Text(
                                "Geçmişe Kaydet",
                                style: GoogleFonts.poppins(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _showImprovementOptions,
                              icon: Icon(Icons.auto_fix_high, size: 18),
                              label: Text(
                                "Geliştir",
                                style: GoogleFonts.poppins(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isGeneratingNotes ? null : generateLectureNotes,
                              icon: _isGeneratingNotes
                                  ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                                  : Icon(Icons.note_alt, size: 18),
                              label: Text(
                                _isGeneratingNotes ? "Oluşturuluyor..." : "Ders Notları",
                                style: GoogleFonts.poppins(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required String content,
    required bool isExpanded,
    required VoidCallback toggleExpansion,
    required AnimationController expandController,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        InkWell(
          onTap: toggleExpansion,
          child: Row(
            children: [
              Icon(icon, color: Colors.deepPurple),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: Duration(milliseconds: 300),
                child: Icon(
                  Icons.expand_more,
                  color: Colors.deepPurple,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 15),

        // İçerik
        AnimatedContainer(
          duration: Duration(milliseconds: 300),
          constraints: BoxConstraints(
            maxHeight: isExpanded
                ? MediaQuery.of(context).size.height * 0.3
                : 120,
          ),
          child: SingleChildScrollView(
            child: Text(
              content,
              style: GoogleFonts.poppins(
                fontSize: 14,
                height: 1.6,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ),

        // Tam Ekran Butonu
        if (!isExpanded) ...[
          const SizedBox(height: 10),
          Center(
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => FullScreenSummaryPage(
                      summary: title == "Özet" ? _summary! : "",
                      highlights: title == "Önemli Noktalar" ? _highlights : "",
                      videoTitle: _videoTitle,
                    ),
                  ),
                );
              },
              icon: Icon(Icons.fullscreen, size: 16),
              label: Text(
                "Tam Ekranda Oku",
                style: GoogleFonts.poppins(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Colors.deepPurple,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class FullScreenSummaryPage extends StatelessWidget {
  final String? summary;
  final String? highlights;
  final String? videoTitle;

  const FullScreenSummaryPage({
    Key? key,
    this.summary,
    this.highlights,
    this.videoTitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          videoTitle ?? "Detaylar",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (summary != null && summary!.isNotEmpty) ...[
              Text(
                "Özet",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade200,
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )],
                ),
                child: Text(
                  summary!,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    height: 1.8,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
            if (highlights != null && highlights!.isNotEmpty) ...[
              Text(
                "Önemli Noktalar",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade200,
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Text(
                  highlights!,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    height: 1.8,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}