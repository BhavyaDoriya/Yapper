import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

      // Fetch ALL known words
      final data = await _supabase.from('known_words').select('word').eq('user_id', user.id);
      List<String> allWords = List<String>.from(data.map((row) => row['word'].toString()));
      
      if (allWords.length < 4) {
        setState(() {
          _errorMessage = "You need at least 4 words in your Memory Bank to enter the Test Arena. Keep studying!";
          _isLoadingQuiz = false;
        });
        return;
      }

      allWords.shuffle();
      List<String> testWords = allWords.take(10).toList();

      await _generateQuizFromAI(testWords);
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to access memory bank: $e";
        _isLoadingQuiz = false;
      });
    }
  }

  Future<void> _generateQuizFromAI(List<String> words) async {
    
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
        
        // Strip out markdown if AI hallucinates it
        String rawContent = jsonDecode(response.body)['choices'][0]['message']['content'];
        rawContent = rawContent.replaceAll('```json', '').replaceAll('```', '').trim();
        
        final aiData = jsonDecode(rawContent);
        
        setState(() {
          _quizQuestions = aiData['quiz'] ?? [];
          _isLoadingQuiz = false;
        });
      } else {
        setState(() {
          _errorMessage = "AI Engine failed to construct quiz. Code: ${response.statusCode}";
          _isLoadingQuiz = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _errorMessage = "Connection error."; _isLoadingQuiz = false; });
    }
  }

  // --- THE FIXED AI GRADER ---
// --- THE FIXED AI GRADER ---
  Future<void> _submitOpenEndedAnswer() async {
    if (_answerController.text.trim().isEmpty) return;
    
    setState(() => _isGrading = true);
    final currentQ = _quizQuestions[_currentIndex];

    try {
      final response = await http.post(
        Uri.parse('https://vocab-proxy-three.vercel.app/api/generate'), // <-- Routed to your secure proxy
        headers: {
          'Content-Type': 'application/json',
          // API key is handled securely by the cloud server now
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
        // Strip markdown to prevent silent JSON parse crashes
        String rawContent = jsonDecode(response.body)['choices'][0]['message']['content'];
        rawContent = rawContent.replaceAll('```json', '').replaceAll('```', '').trim();
        
        final aiData = jsonDecode(rawContent);
        bool isCorrect = aiData['correct'] == true || aiData['correct'] == 'true';
        
        _handleAnswerResult(isCorrect);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("AI Grading failed. Please try again or skip."), backgroundColor: Colors.redAccent));
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
        content: Text(isCorrect ? "Correct! +1" : "Incorrect."),
        backgroundColor: isCorrect ? Colors.green : Colors.redAccent,
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

  // --- ABORT TRIAL DIALOG ---
  Future<bool> _requestExit() async {
    if (_isQuizComplete || _isLoadingQuiz || _errorMessage.isNotEmpty) {
      Navigator.of(context).pop();
      return true;
    }
    
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)), borderRadius: BorderRadius.circular(20)),
        title: Text('ABORT TRIAL?', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        content: Text('Are you sure you want to exit? Your current score will be lost and you cannot resume.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('CONTINUE', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ABORT', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
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

    // Using PopScope to catch Android hardware back buttons
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _requestExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('TEST ARENA', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold)),
          // Catch AppBar back button
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _requestExit),
        ),
        body: SafeArea(
          child: _isLoadingQuiz 
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: theme.colorScheme.primary),
                    const SizedBox(height: 20),
                    Text("Constructing your customized trial...", style: TextStyle(color: theme.colorScheme.primary)),
                  ],
                ),
              )
            : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(30.0),
                    child: Text(_errorMessage, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.error, fontSize: 16)),
                  ),
                )
              : _isQuizComplete
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.military_tech, size: 100, color: theme.colorScheme.primary),
                        const SizedBox(height: 20),
                        Text("TRIAL COMPLETE", style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Text("Score: $_score / ${_quizQuestions.length}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Text("QUESTION ${_currentIndex + 1} OF ${_quizQuestions.length}", style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, letterSpacing: 2)),
                        const SizedBox(height: 20),
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3))),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _quizQuestions[_currentIndex]['question'],
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 30),
                                
                                // --- MULTIPLE CHOICE UI ---
                                if (_quizQuestions[_currentIndex]['type'] == 'mcq') ...[
                                  ...(_quizQuestions[_currentIndex]['options'] as List<dynamic>).map((option) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12.0),
                                    child: OutlinedButton(
                                      onPressed: () => _submitMCQAnswer(option.toString()),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.5)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                      ),
                                      child: Text(option.toString(), style: TextStyle(color: theme.colorScheme.onSurface)),
                                    ),
                                  )),
                                  const SizedBox(height: 20),
                                  // THE SKIP BUTTON
                                  TextButton(
                                    onPressed: () => _handleAnswerResult(false),
                                    child: const Text("Skip Question", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                  ),
                                ] 
                                // --- OPEN ENDED UI ---
                                else ...[
                                  TextField(
                                    controller: _answerController,
                                    maxLines: 3,
                                    decoration: InputDecoration(
                                      hintText: "Type your explanation here...",
                                      filled: true,
                                      fillColor: theme.colorScheme.surface,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton(
                                    onPressed: _isGrading ? null : _submitOpenEndedAnswer,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: theme.colorScheme.primary,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                    ),
                                    child: _isGrading 
                                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                      : Text("SUBMIT FOR GRADING", style: TextStyle(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(height: 10),
                                  // THE SKIP BUTTON
                                  TextButton(
                                    onPressed: _isGrading ? null : () => _handleAnswerResult(false),
                                    child: const Text("Skip Question", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                  ),
                                ]
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
        ),
      ),
    );
  }
}