import 'package:flutter/material.dart';
import '../models/chakula_assessment.dart';
import '../services/firestore_service.dart';

const _ratingLabels = [
  'I was busy but built nothing meaningful',
  'I moved some things but avoided the hard work',
  'Solid week, real progress made',
  'Strong week, I pushed through resistance',
  'Exceptional — I shipped something that actually matters',
];

class ChakulaAssessmentScreen extends StatefulWidget {
  final String uid;
  final String weekKey;
  final bool isSundayFlow;

  const ChakulaAssessmentScreen({
    super.key,
    required this.uid,
    required this.weekKey,
    this.isSundayFlow = false,
  });

  @override
  State<ChakulaAssessmentScreen> createState() =>
      _ChakulaAssessmentScreenState();
}

class _ChakulaAssessmentScreenState extends State<ChakulaAssessmentScreen> {
  List<String>? _deliverables;
  bool _loading = true;

  int? _rating;
  final _unshippedCtrl = TextEditingController();
  String? _unshippedError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadDeliverables();
  }

  Future<void> _loadDeliverables() async {
    final items = await FirestoreService.getChakulaDeliverablesForWeek(
        widget.uid, DateTime.now());
    if (mounted) setState(() { _deliverables = items; _loading = false; });
  }

  @override
  void dispose() {
    _unshippedCtrl.dispose();
    super.dispose();
  }

  String? _validateUnshipped(String text) {
    final words =
        text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.length < 10) {
      return 'Ten words minimum. Be specific about what you avoided.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_rating == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Select a rating first.'),
          backgroundColor: Color(0xFF1A1A2E)));
      return;
    }
    final err = _validateUnshipped(_unshippedCtrl.text);
    if (err != null) {
      setState(() => _unshippedError = err);
      return;
    }
    setState(() => _submitting = true);

    final assessment = ChakulaAssessment(
      weekKey: widget.weekKey,
      rating: _rating!,
      weeklyDeliverables: _deliverables ?? [],
      unshippedReason: _unshippedCtrl.text.trim(),
      completedAt: DateTime.now(),
    );

    await FirestoreService.saveChakulaAssessment(
        widget.uid, widget.weekKey, assessment);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isSunday = widget.isSundayFlow;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D0D1A),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isSunday)
                    const Text(
                      'SUNDAY CHECK-IN · 3 OF 3',
                      style: TextStyle(
                          color: Color(0xFFFF6B35),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5),
                    ),
                  const Text(
                    'CHAKULA ASSESSMENT',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 1),
                  ),
                ],
              ),
            ],
          ),
          bottom: isSunday
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    value: 1.0,
                    backgroundColor: const Color(0xFF1A1A2E),
                    valueColor:
                        const AlwaysStoppedAnimation(Color(0xFFFF6B35)),
                    minHeight: 3,
                  ),
                )
              : null,
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Deliverables this week
                          if ((_deliverables ?? []).isNotEmpty) ...[
                            _label('WHAT YOU SHIPPED THIS WEEK'),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A2E),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: (_deliverables ?? [])
                                    .map((d) => Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 8),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Padding(
                                                padding: EdgeInsets.only(
                                                    top: 3),
                                                child: Icon(
                                                    Icons
                                                        .check_circle_outline,
                                                    color:
                                                        Color(0xFF00C853),
                                                    size: 14),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(d,
                                                    style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 13,
                                                        height: 1.4)),
                                              ),
                                            ],
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A0A0A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFFFF4444)
                                        .withValues(alpha: 0.3)),
                              ),
                              child: const Text(
                                'No Chakula deliverables logged this week.',
                                style: TextStyle(
                                    color: Color(0xFFFF6666), fontSize: 13),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Rating prompt
                          const Text(
                            'Looking at what you actually shipped this week, rate its real impact on Chakula\'s progress.',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                height: 1.4),
                          ),
                          const SizedBox(height: 16),

                          // 1-5 selector
                          ...List.generate(5, (i) {
                            final value = i + 1;
                            final selected = _rating == value;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _rating = value),
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 150),
                                margin:
                                    const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFF1A2A1A)
                                      : const Color(0xFF1A1A2E),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected
                                        ? const Color(0xFF00C853)
                                        : const Color(0xFF2A2A4A),
                                    width: selected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(
                                          milliseconds: 150),
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: selected
                                            ? const Color(0xFF00C853)
                                            : const Color(0xFF2A2A4A),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$value',
                                          style: TextStyle(
                                            color: selected
                                                ? Colors.black
                                                : Colors.white54,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        _ratingLabels[i],
                                        style: TextStyle(
                                          color: selected
                                              ? Colors.white
                                              : Colors.white54,
                                          fontSize: 13,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),

                          const SizedBox(height: 24),

                          // Unshipped reason
                          _label(
                              'WHAT WAS THE MOST IMPORTANT THING YOU DID NOT SHIP THIS WEEK AND WHY?'),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _unshippedCtrl,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5),
                            maxLines: 5,
                            onChanged: (_) =>
                                setState(() => _unshippedError = null),
                            decoration: InputDecoration(
                              hintText:
                                  'The thing I didn\'t ship was... because...',
                              hintStyle: const TextStyle(
                                  color: Colors.white24, fontSize: 13),
                              filled: true,
                              fillColor: const Color(0xFF1A1A2E),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFFFF6B35), width: 1.5),
                              ),
                            ),
                          ),
                          if (_unshippedError != null) ...[
                            const SizedBox(height: 6),
                            Text(_unshippedError!,
                                style: const TextStyle(
                                    color: Color(0xFFFF5555), fontSize: 12)),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Submit bar
                  Container(
                    color: const Color(0xFF12122A),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B35),
                          disabledBackgroundColor:
                              const Color(0xFF3A2A20),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : const Text('Complete Sunday Check-in'),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5),
      );
}
