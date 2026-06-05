import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- OPPDATERET MATHPROBLEM TIL AT KUNNE GEMMES LOKALT ---
class MathProblem {
  final String questionText;
  final int correctAnswer;
  int? userAnswer;
  bool? isCorrect;

  MathProblem({
    required this.questionText, 
    required this.correctAnswer,
    this.userAnswer,
    this.isCorrect,
  });

  // Konverterer til JSON
  Map<String, dynamic> toJson() => {
        'q': questionText,
        'c': correctAnswer,
        'u': userAnswer,
        'i': isCorrect,
      };

  // Henter fra JSON
  factory MathProblem.fromJson(Map<String, dynamic> json) => MathProblem(
        questionText: json['q'],
        correctAnswer: json['c'],
        userAnswer: json['u'],
        isCorrect: json['i'],
      );
}

class MatOpgPopup extends StatefulWidget {
  final DocumentReference taskRef;
  final String level;
  final int problemCount;
  final double passCriteria;
  final Map<String, dynamic> activeTypes;

  const MatOpgPopup({
    super.key,
    required this.taskRef,
    required this.level,
    required this.problemCount,
    required this.passCriteria,
    required this.activeTypes,
  });

  @override
  State<MatOpgPopup> createState() => _MatOpgPopupState();
}

class _MatOpgPopupState extends State<MatOpgPopup> {
  late PageController _pageController;
  final TextEditingController _answerCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  List<MathProblem> _problems = [];
  int _currentIndex = 0;
  bool _isSaving = false;
  bool _isLoading = true; // Holder styr på loading fra local storage
  
  bool _isKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    _initProblems(); // Henter eller genererer opgaver
    
    _focusNode.addListener(() {
      setState(() {
        _isKeyboardVisible = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    if (!_isLoading) _pageController.dispose();
    _answerCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // --- HENT ELLER GENERER OPGAVER LOKALT ---
  Future<void> _initProblems() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString('math_${widget.taskRef.id}');

    if (savedData != null) {
      // Vi fandt gemt offline data
      final List<dynamic> decoded = jsonDecode(savedData);
      _problems = decoded.map((e) => MathProblem.fromJson(e)).toList();
    } else {
      // Første gang opgaven åbnes, generer nye
      _generateProblems();
      _saveProblemsLocally();
    }

    // Find første ubesvarede opgave at starte på
    int startIdx = 0;
    int firstUnanswered = _problems.indexWhere((p) => p.userAnswer == null);
    if (firstUnanswered != -1) {
      startIdx = firstUnanswered;
    }
    
    _currentIndex = startIdx;
    _pageController = PageController(initialPage: startIdx);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _answerCtrl.text = _problems[_currentIndex].userAnswer?.toString() ?? '';
      });
    }
  }

  // --- GEM LOKALT I BAGGRUNDEN ---
  Future<void> _saveProblemsLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_problems.map((e) => e.toJson()).toList());
    await prefs.setString('math_${widget.taskRef.id}', encoded);
  }

  void _generateProblems() {
    final rand = Random();
    List<String> types = [];
    if (widget.activeTypes['Plus'] == true) types.add('+');
    if (widget.activeTypes['Minus'] == true) types.add('-');
    if (widget.activeTypes['Gange'] == true) types.add('*');
    
    if (types.isEmpty) types.add('+');

    for (int i = 0; i < widget.problemCount; i++) {
      String op = types[rand.nextInt(types.length)];
      int a = 0;
      int b = 0;
      int answer = 0;

      if (widget.level == 'Let') {
        if (op == '+') {
          a = rand.nextInt(11);
          b = rand.nextInt(11);
          answer = a + b;
        } else if (op == '-') {
          a = rand.nextInt(16) + 5;
          b = rand.nextInt(a + 1);
          answer = a - b;
        } else if (op == '*') {
          a = rand.nextInt(6);
          b = rand.nextInt(6);
          answer = a * b;
        }
      } 
      else if (widget.level == 'Øvet') {
        if (op == '+') {
          a = rand.nextInt(90) + 10;
          b = rand.nextInt(50) + 10;
          answer = a + b;
        } else if (op == '-') {
          a = rand.nextInt(90) + 10;
          b = rand.nextInt(a);
          answer = a - b;
        } else if (op == '*') {
          a = rand.nextInt(10) + 1;
          b = rand.nextInt(10) + 1;
          answer = a * b;
        }
      } 
      else {
        if (op == '+') {
          a = rand.nextInt(900) + 100;
          b = rand.nextInt(900) + 100;
          answer = a + b;
        } else if (op == '-') {
          a = rand.nextInt(900) + 100;
          b = rand.nextInt(a);
          answer = a - b;
        } else if (op == '*') {
          a = rand.nextInt(90) + 10;
          b = rand.nextInt(9) + 2;
          answer = a * b;
        }
      }

      String opSymbol = op;
      if (op == '*') opSymbol = 'x';
      
      _problems.add(MathProblem(questionText: '$a $opSymbol $b =', correctAnswer: answer));
    }
  }

  void _onAnswerSubmitted() {
    int? parsedAns = int.tryParse(_answerCtrl.text.trim());
    
    setState(() {
      _problems[_currentIndex].userAnswer = parsedAns;
      if (parsedAns != null) {
        _problems[_currentIndex].isCorrect = (parsedAns == _problems[_currentIndex].correctAnswer);
      } else {
        _problems[_currentIndex].isCorrect = null;
      }
    });

    _saveProblemsLocally();

    if (_currentIndex < _problems.length - 1) {
      _goToNext();
    } else {
      _focusNode.unfocus();
      _finishAndSave();
    }
  }

  void _goToNext() {
    if (_currentIndex < _problems.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _goToPrev() {
    if (_currentIndex > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  Future<void> _finishAndSave() async {
    int correctAnswers = _problems.where((p) => p.isCorrect == true).length;
    double percentage = (correctAnswers / _problems.length) * 100;
    bool passed = percentage >= widget.passCriteria;

    setState(() => _isSaving = true);

    try {
      if (passed) {
        await widget.taskRef.update({'udfoertGange': FieldValue.increment(1)});
        
        // Slet den lokale cache, når opgaven er gennemført og sendt til Firestore
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('math_${widget.taskRef.id}');
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF2A2A30),
            title: Text(passed ? '🎉 Godt gået!' : 'Øv!', style: const TextStyle(color: Colors.white)),
            content: Text(
              passed 
                ? 'Du svarede rigtigt på $correctAnswers ud af ${_problems.length} opgaver og har bestået matematik opgaven!' 
                : 'Du fik $correctAnswers ud af ${_problems.length} rigtige. Det kræver ${widget.passCriteria.toInt()}% at bestå.\n\nPrøv igen senere!',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('Afslut', style: TextStyle(color: Color(0xFFFF6B35), fontSize: 18, fontWeight: FontWeight.bold)),
              )
            ],
          )
        );
      }
    } catch (e) {
      debugPrint("Fejl ved gem: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFF121214),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35))),
      );
    }

    return GestureDetector(
      onTap: () => _focusNode.unfocus(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(
          color: Color(0xFF121214),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Matematik Opgave', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            
            // --- TOP CIRKLER ---
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: _isKeyboardVisible ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: List.generate(_problems.length, (index) {
                        final problem = _problems[index];
                        Color circleColor = const Color(0xFF2A2A30);
                        Color borderColor = Colors.transparent;

                        if (problem.isCorrect == true) {
                          circleColor = const Color(0xFF008D3D);
                        } else if (problem.isCorrect == false) {
                          circleColor = Colors.redAccent;
                        } else if (index == _currentIndex) {
                          borderColor = const Color(0xFFFF6B35);
                        }

                        return GestureDetector(
                          onTap: () {
                            _onAnswerSubmitted();
                            _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: circleColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: borderColor, width: 2),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const Divider(color: Color(0xFF3F3F46)),
                ],
              ),
              secondChild: const SizedBox(width: double.infinity, height: 0),
            ),

            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (idx) {
                  setState(() {
                    _currentIndex = idx;
                    _answerCtrl.text = _problems[idx].userAnswer?.toString() ?? '';
                  });
                },
                itemCount: _problems.length,
                itemBuilder: (context, index) {
                  final prob = _problems[index];
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    prob.questionText,
                                    style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: 150,
                                    child: TextField(
                                      controller: _answerCtrl,
                                      focusNode: _focusNode,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: const Color(0xFF2A2A30),
                                        hintText: '?',
                                        hintStyle: const TextStyle(color: Colors.white24),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2)),
                                      ),
                                      onSubmitted: (_) => _onAnswerSubmitted(),
                                      onChanged: (val) {
                                        int? parsed = int.tryParse(val.trim());
                                        _problems[_currentIndex].userAnswer = parsed;
                                        _saveProblemsLocally();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // --- BUNDSEKTION ---
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: _isKeyboardVisible ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              
              // LAYOUT 1: TASTATUR NEDE (Svar-knap øverst, pile nederst + plads til Android Navigation)
              firstChild: Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.of(context).padding.bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSvarButton(),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildNavButton(Icons.arrow_back_rounded, _currentIndex > 0 ? _goToPrev : null),
                        Text('Opgave ${_currentIndex + 1} af ${_problems.length}', style: const TextStyle(color: Colors.white54, fontSize: 16)),
                        _buildNavButton(Icons.arrow_forward_rounded, _currentIndex < _problems.length - 1 ? _goToNext : null),
                      ],
                    ),
                  ],
                ),
              ),

              // LAYOUT 2: TASTATUR OPPE (Pile på hver side af Svar-knap)
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Row(
                  children: [
                    _buildNavButton(Icons.arrow_back_rounded, _currentIndex > 0 ? _goToPrev : null),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSvarButton()),
                    const SizedBox(width: 12),
                    _buildNavButton(Icons.arrow_forward_rounded, _currentIndex < _problems.length - 1 ? _goToNext : null),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Hjælpefunktion til at bygge selve Svar-knappen
  Widget _buildSvarButton() {
    return SizedBox(
      height: 60,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _onAnswerSubmitted,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B35),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                _currentIndex == _problems.length - 1 ? 'Svar & Afslut' : 'Svar', 
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)
              ),
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback? onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Opacity(
        opacity: onPressed == null ? 0.3 : 1.0,
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            color: Colors.transparent,
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}