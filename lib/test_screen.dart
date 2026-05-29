import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dusty_atmosphere.dart'; // THE PHYSICS ENGINE

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _answerController = TextEditingController();
  
  List<dynamic> _quizQuestions = [];
  int _currentIndex = 0;
  int _score = 0;
  
  bool _isLoadingQuiz = true;
  bool _isGrading = false;
  bool _isQuizComplete = false;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _initializeQuiz();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _initializeQuiz() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase.from('known_words').select('word').eq('user_id', user.id);
      List<String> allWords = List<String>.from(data.map((row) => row['word'].toString()));
      
      if (allWords.length < 4) {
        if (mounted) {
          setState(() {
            _errorMessage = "You need at least 4 words in your Memory Bank to enter the Test Arena. Keep studying!";
            _isLoadingQuiz = false;
          });
        }
        return;
      }

      allWords.shuffle();
      List<String> testWords = allWords.take(10).toList();

      await _generateQuizFromAI(testWords);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to access memory bank: $e";
          _isLoadingQuiz = false;
        });
      }
    }
  }

  Future<void> _generateQuizFromAI(List<String> words) async {
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
              "content": "You are a quiz generator. Create a quiz using exactly the words provided. Return a JSON object with a single key 'quiz' containing an array of question objects. Randomly mix two types of objects: 1) {\"type\": \"open\", \"word\": \"...\", \"question\": \"Explain the meaning of '...' in your own words.\"} AND 2) {\"type\": \"mcq\", \"word\": \"...\", \"question\": \"Which is a synonym/antonym for '...'?\", \"options\": [\"A\", \"B\", \"C\", \"D\"], \"answer\": \"Correct Option\"}."
            },
            {
              "role": "user",
              "content": "Generate a ${words.length}-question quiz for these words: ${words.join(', ')}"
            }
          ],
          "temperature": 0.7, 
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        
        String rawContent = jsonDecode(response.body)['choices'][0]['message']['content'];
        rawContent = rawContent.replaceAll('```json', '').replaceAll('```', '').trim();
        
        final aiData = jsonDecode(rawContent);
        
        setState(() {
          _quizQuestions = aiData['quiz'] ?? [];
          _isLoadingQuiz = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = "AI Engine failed to construct quiz. Code: ${response.statusCode}";
            _isLoadingQuiz = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() { _errorMessage = "Connection error."; _isLoadingQuiz = false; });
    }
  }

  Future<void> _submitOpenEndedAnswer() async {
    if (_answerController.text.trim().isEmpty) return;
    
    setState(() => _isGrading = true);
    final currentQ = _quizQuestions[_currentIndex];

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
              "content": "You are a strict JSON API. Read the user's explanation of the word. Evaluate if it is generally correct. You MUST return ONLY a valid JSON object: {\"correct\": true} or {\"correct\": false}. No markdown, no extra text."
            },
            {
              "role": "user",
              "content": "Word: ${currentQ['word']}. User Explanation: ${_answerController.text.trim()}"
            }
          ]
        }),
      );

      if (response.statusCode == 200 && mounted) {
        String rawContent = jsonDecode(response.body)['choices'][0]['message']['content'];
        rawContent = rawContent.replaceAll('```json', '').replaceAll('```', '').trim();
        
        final aiData = jsonDecode(rawContent);
        bool isCorrect = aiData['correct'] == true || aiData['correct'] == 'true';
        
        _handleAnswerResult(isCorrect);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("AI Grading failed. Please try again or skip."), backgroundColor: Colors.redAccent));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isGrading = false);
    }
  }

  void _submitMCQAnswer(String selectedOption) {
    final currentQ = _quizQuestions[_currentIndex];
    bool isCorrect = (selectedOption == currentQ['answer']);
    _handleAnswerResult(isCorrect);
  }

  void _handleAnswerResult(bool isCorrect) {
    if (isCorrect) _score++;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isCorrect ? "CORRECT (+1)" : "INCORRECT", style: const TextStyle(letterSpacing: 2.0, fontWeight: FontWeight.bold)),
        backgroundColor: isCorrect ? const Color(0xFF2E7D32) : Colors.redAccent, 
        duration: const Duration(milliseconds: 1000),
      ),
    );

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      setState(() {
        _answerController.clear();
        if (_currentIndex < _quizQuestions.length - 1) {
          _currentIndex++;
        } else {
          _isQuizComplete = true;
        }
      });
    });
  }

  Future<bool> _requestExit() async {
    if (_isQuizComplete || _isLoadingQuiz || _errorMessage.isNotEmpty) {
      Navigator.of(context).pop();
      return true;
    }
    
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111114), 
        shape: Border.all(color: Colors.redAccent.withOpacity(0.5), width: 1), 
        title: const Text('ABORT TRIAL?', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
        content: Text('Are you sure you want to exit? Your current score will be lost and you cannot resume.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('CONTINUE', style: TextStyle(color: Theme.of(context).colorScheme.primary, letterSpacing: 1.5)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ABORT', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
          ),
        ],
      ),
    );
    
    if (shouldExit == true && mounted) {
      Navigator.of(context).pop();
    }
    return shouldExit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _requestExit();
      },
      child: Stack(
        children: [
          const DustyAtmosphere(), 

          Scaffold(
            backgroundColor: Colors.transparent, 
            appBar: AppBar(
              title: const Text('TEST ARENA', style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.bold, fontSize: 14)),
              leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _requestExit),
            ),
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: 600, 
                  child: _isLoadingQuiz 
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: theme.colorScheme.primary),
                            const SizedBox(height: 20),
                            Text("CONSTRUCTING TRIAL...", style: TextStyle(color: theme.colorScheme.primary, letterSpacing: 2.0)),
                          ],
                        ),
                      )
                    : _errorMessage.isNotEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(30.0),
                            child: Text(_errorMessage, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.error, fontSize: 16, letterSpacing: 1.5)),
                          ),
                        )
                      : _isQuizComplete
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.military_tech, size: 80, color: theme.colorScheme.primary),
                                const SizedBox(height: 20),
                                Text("TRIAL COMPLETE", style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, letterSpacing: 4)),
                                const SizedBox(height: 20),
                                Text("SCORE: $_score / ${_quizQuestions.length}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
                                const SizedBox(height: 60),
                                
                                InkWell(
                                  onTap: () => Navigator.pop(context),
                                  child: Text("RETURN TO HUB", style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, letterSpacing: 3.0, fontSize: 14)),
                                )
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              children: [
                                Text("QUESTION ${_currentIndex + 1} OF ${_quizQuestions.length}", style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4), fontWeight: FontWeight.bold, letterSpacing: 3, fontSize: 10)),
                                const SizedBox(height: 40),
                                
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(color: theme.colorScheme.primary.withOpacity(0.2), width: 1),
                                      bottom: BorderSide(color: theme.colorScheme.primary.withOpacity(0.2), width: 1),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        _quizQuestions[_currentIndex]['question'],
                                        style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary, letterSpacing: 1.0),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 40),
                                      
                                      if (_quizQuestions[_currentIndex]['type'] == 'mcq') ...[
                                        ...(_quizQuestions[_currentIndex]['options'] as List<dynamic>).map((option) => InkWell(
                                          onTap: () => _submitMCQAnswer(option.toString()),
                                          child: Container(
                                            margin: const EdgeInsets.only(bottom: 12.0),
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            decoration: BoxDecoration(
                                              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3), width: 1),
                                              color: theme.colorScheme.surface.withOpacity(0.1),
                                            ),
                                            child: Text(option.toString(), textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.onSurface, letterSpacing: 1.5, fontSize: 16)),
                                          ),
                                        )),
                                      ] 
                                      else ...[
                                        TextField(
                                          controller: _answerController,
                                          maxLines: 3,
                                          style: const TextStyle(letterSpacing: 1.5),
                                          decoration: InputDecoration(
                                            hintText: "Enter your tactical analysis...",
                                            hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.2)),
                                            enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24, width: 1), borderRadius: BorderRadius.zero),
                                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5), borderRadius: BorderRadius.zero),
                                          ),
                                        ),
                                        const SizedBox(height: 30),
                                        
                                        InkWell(
                                          onTap: _isGrading ? null : _submitOpenEndedAnswer,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            decoration: BoxDecoration(
                                              border: Border.all(color: theme.colorScheme.primary, width: 1.5),
                                              color: theme.colorScheme.primary.withOpacity(0.1),
                                            ),
                                            child: _isGrading 
                                              ? Center(child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary)))
                                              : Center(child: Text("SUBMIT ANALYSIS", style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, letterSpacing: 2.0))),
                                          ),
                                        ),
                                      ],
                                      
                                      const SizedBox(height: 40),
                                      InkWell(
                                        onTap: _isGrading ? null : () => _handleAnswerResult(false),
                                        child: Text("SKIP DIRECTIVE", textAlign: TextAlign.center, style: TextStyle(color: Colors.redAccent.withOpacity(0.8), fontWeight: FontWeight.bold, letterSpacing: 2.0, fontSize: 10)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}