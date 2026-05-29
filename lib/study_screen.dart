import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dusty_atmosphere.dart'; // THE PHYSICS ENGINE

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
      // 1. GET THE USER'S SECURE BADGE
      final session = _supabase.auth.currentSession;
      if (session == null) throw Exception("Unauthorized: No secure session found.");
      final token = session.accessToken; 

      final response = await http.post(
        Uri.parse('https://vocab-proxy-three.vercel.app/api/generate'), 
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // 2. SHOW THE BADGE TO VERCEL
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
      if (isReplacement && mounted) setState(() => isFetchingReplacement = false);
    }
  }

  void _nextWord() async {
    if (wordQueue.isEmpty) return;

    final currentWordMap = wordQueue[currentIndex];
    final wordToSave = currentWordMap['word'];

    setState(() {
      reviewedCount++;
      showDetails = false;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        try {
          await _supabase.from('known_words').insert({'user_id': userId, 'word': wordToSave});
        } catch (e) {
          if (!e.toString().contains('23505')) print("Progress Save Error: $e");
        }
        
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

  Future<void> _iKnowThis() async {
    if (wordQueue.isEmpty || isFetchingReplacement) return;

    setState(() => isFetchingReplacement = true);

    final currentWordMap = wordQueue[currentIndex];
    final wordToSave = currentWordMap['word'];

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        try {
          await _supabase.from('known_words').insert({'user_id': userId, 'word': wordToSave});
        } catch (e) {
          if (!e.toString().contains('23505')) print("Trash Save Error: $e");
        }
      }
    } catch (e) {
      print("DB Error: $e");
    }

    await _fetchWordsFromAI(count: 1, isReplacement: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); 
    int currentWordDisplay = widget.wordsAlreadyCleared + reviewedCount + 1;
    int totalGoalDisplay = widget.wordsAlreadyCleared + widget.batchSize;

    return Stack(
      children: [
        const DustyAtmosphere(),

        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text('${widget.activeCategory.toUpperCase()} QUEUE', style: const TextStyle(fontSize: 14, letterSpacing: 4)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context), 
            ),
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 600, // THE STRAITJACKET
                child: isFetchingBatch && wordQueue.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: theme.colorScheme.primary),
                          const SizedBox(height: 20),
                          Text("EXTRACTING BATCH...", style: TextStyle(color: theme.colorScheme.primary, letterSpacing: 2.0)),
                        ],
                      ),
                    )
                  : isSessionComplete 
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("BATCH COMPLETE", style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, letterSpacing: 4)),
                            const SizedBox(height: 10),
                            Text("You have cleared your queue for today.", style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                            const SizedBox(height: 60),
                            
                            // Custom inline action
                            InkWell(
                              onTap: () => Navigator.pop(context),
                              child: Text("RETURN TO HUB", style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, letterSpacing: 3.0, fontSize: 14)),
                            )
                          ],
                        ),
                      )
                    : SingleChildScrollView( 
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "WORD $currentWordDisplay OF $totalGoalDisplay", 
                              style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4), fontWeight: FontWeight.bold, letterSpacing: 3, fontSize: 10)
                            ), 
                            const SizedBox(height: 40),
                            
                            // The Tactical Floating Word Panel
                            AnimatedSize( 
                              duration: const Duration(milliseconds: 300),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: theme.colorScheme.primary.withOpacity(0.2), width: 1),
                                    bottom: BorderSide(color: theme.colorScheme.primary.withOpacity(0.2), width: 1),
                                  ),
                                ),
                                child: isFetchingReplacement
                                  ? Column(
                                      children: [
                                        CircularProgressIndicator(color: theme.colorScheme.primary),
                                        const SizedBox(height: 16),
                                        Text("ACQUIRING REPLACEMENT...", style: TextStyle(color: theme.colorScheme.primary, letterSpacing: 2.0, fontSize: 10)),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        Text(
                                          wordQueue.isNotEmpty ? wordQueue[currentIndex]['word'].toString().toUpperCase() : "ERROR",
                                          style: theme.textTheme.displayMedium?.copyWith(color: theme.colorScheme.primary, letterSpacing: 2.0),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 24),
                                        Text(
                                          wordQueue.isNotEmpty ? wordQueue[currentIndex]['definition'] : "",
                                          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 40),
                                        
                                        InkWell(
                                          onTap: () => setState(() => showDetails = !showDetails),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(showDetails ? "HIDE DATA" : "VIEW EXAMPLES", style: TextStyle(color: theme.colorScheme.primary.withOpacity(0.6), letterSpacing: 2.0, fontSize: 10, fontWeight: FontWeight.bold)),
                                              const SizedBox(width: 8),
                                              Icon(showDetails ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: theme.colorScheme.primary.withOpacity(0.6), size: 16),
                                            ],
                                          )
                                        ),

                                        if (showDetails && wordQueue.isNotEmpty) ...[
                                          const SizedBox(height: 30),
                                          Text("EXAMPLES", style: TextStyle(color: theme.colorScheme.primary.withOpacity(0.5), fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 2.0)),
                                          const SizedBox(height: 16),
                                          ...(wordQueue[currentIndex]['examples'] as List<dynamic>).map((example) => Padding(
                                            padding: const EdgeInsets.only(bottom: 12.0),
                                            child: Text("\"$example\"", style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.8), fontSize: 16, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                                          )),
                                        ]
                                      ],
                                    ),
                              ),
                            ),
                            const SizedBox(height: 60),

                            // INLINE TACTICAL ACTIONS
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                InkWell(
                                  onTap: (isFetchingReplacement || isFetchingBatch) ? null : _iKnowThis,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3), width: 1),
                                    ),
                                    child: Text("I KNOW THIS", style: TextStyle(color: theme.colorScheme.primary.withOpacity(0.8), letterSpacing: 2.0, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(width: 24),
                                InkWell(
                                  onTap: (isFetchingReplacement || isFetchingBatch) ? null : _nextWord,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withOpacity(0.1),
                                      border: Border.all(color: theme.colorScheme.primary, width: 1.5),
                                    ),
                                    child: Row(
                                      children: [
                                        Text("NEXT", style: TextStyle(color: theme.colorScheme.primary, letterSpacing: 2.0, fontSize: 12, fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 8),
                                        Icon(Icons.arrow_forward_ios, size: 12, color: theme.colorScheme.primary),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}