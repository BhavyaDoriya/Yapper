import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudyScreen extends StatefulWidget {
  final int batchSize;
  final int wordsAlreadyCleared;
  final String activeCategory;

  const StudyScreen({
    super.key, 
    required this.batchSize, 
    required this.wordsAlreadyCleared,
    required this.activeCategory
  });

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  final _supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> wordQueue = [];
  List<String> seenWords = [];
  
  int currentIndex = 0;
  int reviewedCount = 0; 
  
  bool isFetchingBatch = true;
  bool isFetchingReplacement = false; 
  bool showDetails = false;
  bool isSessionComplete = false;

  @override
  void initState() {
    super.initState();
    _initializeQueue();
  }

  Future<void> _initializeQueue() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      final data = await _supabase.from('known_words').select('word').eq('user_id', user.id);
      seenWords = List<String>.from(data.map((row) => row['word'].toString()));
    }
    
    await _fetchWordsFromAI(count: widget.batchSize, isReplacement: false); 
  }

  Future<void> _fetchWordsFromAI({required int count, required bool isReplacement}) async {
    
    try {
      final response = await http.post(
        Uri.parse('https://vocab-proxy-three.vercel.app/api/generate'), // <-- YOUR CLOUD SERVER
        headers: {
          'Content-Type': 'application/json',
          // NO API KEY HERE! The cloud handles it.
        },
        body: jsonEncode({
          "model": "llama-3.3-70b-versatile", 
          "response_format": {"type": "json_object"}, 
          "messages": [
            {
              "role": "system",
              "content": "You are an AI vocabulary generator. You MUST return a JSON object containing a single key called 'words'. The value of 'words' MUST be an array of exactly $count unique JSON objects. Each object must have these four keys: 'word' (string, lowercase), 'definition' (string, simple everyday language), 'examples' (array of 2 strings), 'synonyms' (array of 3 strings)."
            },
            {
              "role": "user",
              "content": "Category: ${widget.activeCategory}. CRITICAL: Do NOT generate any of these words: ${seenWords.join(', ')}."
            }
          ],
          "temperature": 1.0, 
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return; 

        final contentString = jsonDecode(response.body)['choices'][0]['message']['content'];
        final aiData = jsonDecode(contentString);
        
        List<dynamic> fetchedWords = aiData['words'] ?? [];
        
        if (fetchedWords.length > count) {
          fetchedWords = fetchedWords.take(count).toList();
        }
        
        setState(() {
          if (isReplacement && fetchedWords.isNotEmpty) {
            var item = fetchedWords[0];
            wordQueue[currentIndex] = {
              'word': item['word'].toString().toLowerCase(),
              'definition': item['definition'],
              'examples': List<String>.from(item['examples'] ?? []),
              'synonyms': List<String>.from(item['synonyms'] ?? [])
            };
            seenWords.add(item['word'].toString().toLowerCase());
            isFetchingReplacement = false;
          } else {
            for (var item in fetchedWords) {
              wordQueue.add({
                'word': item['word'].toString().toLowerCase(),
                'definition': item['definition'],
                'examples': List<String>.from(item['examples'] ?? []),
                'synonyms': List<String>.from(item['synonyms'] ?? [])
              });
              seenWords.add(item['word'].toString().toLowerCase()); 
            }
            isFetchingBatch = false;
          }
        });
      }
    } catch (e) {
      print("Batch fetch failed: $e");
      if (isReplacement) setState(() => isFetchingReplacement = false);
    }
  }

  // --- THE "NEXT" BUTTON LOGIC (LIVE SAVING) ---
  // --- THE "NEXT" BUTTON LOGIC (LIVE SAVING) ---
  void _nextWord() async {
    if (wordQueue.isEmpty) return;

    final currentWordMap = wordQueue[currentIndex];
    final wordToSave = currentWordMap['word'];

    setState(() {
      reviewedCount++;
      showDetails = false;
    });

    // SECURE THE PROGRESS CARD-BY-CARD
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        // 1. Formally add to known_words. Catch and ignore duplicate errors!
        try {
          await _supabase.from('known_words').insert({'user_id': userId, 'word': wordToSave});
        } catch (e) {
          if (!e.toString().contains('23505')) print("Progress Save Error: $e");
        }
        
        // 2. Update dashboard progress instantly
        String today = DateTime.now().toIso8601String().split('T')[0];
        int totalClearedNow = widget.wordsAlreadyCleared + reviewedCount;
        
        await _supabase.from('profiles').update({
          'words_cleared_today': totalClearedNow,
          'last_completed_date': today
        }).eq('id', userId);
      }
    } catch (e) {
      print("Profile Update Error: $e");
    }

    setState(() {
      if (reviewedCount >= widget.batchSize || currentIndex >= wordQueue.length - 1) {
        isSessionComplete = true;
      } else {
        currentIndex++;
      }
    });
  }

  // --- THE "I KNOW THIS" REPLACEMENT LOGIC ---
  Future<void> _iKnowThis() async {
    if (wordQueue.isEmpty || isFetchingReplacement) return;

    setState(() => isFetchingReplacement = true);

    final currentWordMap = wordQueue[currentIndex];
    final wordToSave = currentWordMap['word'];

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        // Toss the easy word in the trash database. Catch and ignore duplicates!
        try {
          await _supabase.from('known_words').insert({'user_id': userId, 'word': wordToSave});
        } catch (e) {
          if (!e.toString().contains('23505')) print("Trash Save Error: $e");
        }
      }
    } catch (e) {
      print("DB Error: $e");
    }

    // Fetch exactly 1 replacement word.
    await _fetchWordsFromAI(count: 1, isReplacement: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); 
    
    // ABSOLUTE MATH FOR UI
    int currentWordDisplay = widget.wordsAlreadyCleared + reviewedCount + 1;
    int totalGoalDisplay = widget.wordsAlreadyCleared + widget.batchSize;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.activeCategory.toUpperCase()} QUEUE', style: const TextStyle(fontSize: 14, letterSpacing: 2)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context), 
        ),
      ),
      body: SafeArea(
        child: isFetchingBatch && wordQueue.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: theme.colorScheme.primary),
                    const SizedBox(height: 20),
                    Text("Fetching your daily batch...", style: TextStyle(color: theme.colorScheme.primary)),
                  ],
                ),
              )
            : isSessionComplete 
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.verified, size: 80, color: Colors.amber), 
                        const SizedBox(height: 20),
                        Text("BATCH COMPLETE", style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, letterSpacing: 2)),
                        const SizedBox(height: 10),
                        Text("You've cleared your queue for today.", style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                        const SizedBox(height: 40),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16)),
                          child: Text("RETURN TO HUB", style: TextStyle(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  )
                : SingleChildScrollView( 
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // THE FLAWLESS ABSOLUTE COUNTER
                        Text(
                          "WORD $currentWordDisplay OF $totalGoalDisplay", 
                          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12)
                        ), 
                        const SizedBox(height: 20),
                        
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 30.0),
                          child: Card(
                            child: AnimatedSize( 
                              duration: const Duration(milliseconds: 300),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
                                child: isFetchingReplacement
                                  ? Column(
                                      children: [
                                        CircularProgressIndicator(color: theme.colorScheme.primary),
                                        const SizedBox(height: 16),
                                        Text("Extracting replacement word...", style: TextStyle(color: theme.colorScheme.primary)),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        Text(
                                          wordQueue.isNotEmpty ? wordQueue[currentIndex]['word'] : "Empty Queue",
                                          style: theme.textTheme.displaySmall?.copyWith(fontFamily: 'Serif'),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          wordQueue.isNotEmpty ? wordQueue[currentIndex]['definition'] : "",
                                          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16, fontStyle: FontStyle.italic),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 20),
                                        
                                        TextButton.icon(
                                          onPressed: () => setState(() => showDetails = !showDetails),
                                          icon: Icon(showDetails ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: theme.colorScheme.primary),
                                          label: Text(showDetails ? "Hide Details" : "View Examples & Synonyms", style: TextStyle(color: theme.colorScheme.primary)),
                                        ),

                                        if (showDetails && wordQueue.isNotEmpty) ...[
                                          const SizedBox(height: 20),
                                          const Divider(color: Colors.white24),
                                          const SizedBox(height: 10),
                                          
                                          Text("EXAMPLES", style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                                          const SizedBox(height: 10),
                                          ...(wordQueue[currentIndex]['examples'] as List<String>).map((example) => Padding(
                                            padding: const EdgeInsets.only(bottom: 8.0),
                                            child: Text("\"$example\"", style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.8), fontSize: 14), textAlign: TextAlign.center),
                                          )),
                                        ]
                                      ],
                                    ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 50),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: (isFetchingReplacement || isFetchingBatch) ? null : _iKnowThis,
                              icon: const Icon(Icons.check_circle_outline, size: 20),
                              label: const Text("I know this"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.colorScheme.primary,
                                side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: (isFetchingReplacement || isFetchingBatch) ? null : _nextWord, 
                              icon: Icon(Icons.arrow_forward_ios, size: 16, color: theme.colorScheme.onPrimary),
                              label: Text("Next", style: TextStyle(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
      ),
    );
  }
}