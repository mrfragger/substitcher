import 'dart:math';
import 'package:flutter/material.dart';
import '../alif/alif_letters.dart';
import '../alif/alif_audio_player.dart';

class AlifPanel extends StatefulWidget {
  const AlifPanel({super.key});

  @override
  State<AlifPanel> createState() => _AlifPanelState();
}

class _AlifPanelState extends State<AlifPanel> {
  AlifLetter? _selected;
  final List<AlifLetter?> _displayItems = buildAlifDisplayItems();

  void _playLetter(AlifLetter letter) {
    setState(() => _selected = letter);
    AlifAudioPlayer.instance.playLetter(letter.audioAsset);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          const _AlifGuessSection(),
          const Divider(color: Colors.white12, height: 1),
          _buildDetailHeader(_selected),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _displayItems.length,
                  itemBuilder: (context, index) {
                    final item = _displayItems[index];
                    if (item == null) {
                      return const SizedBox.shrink();
                    }
                    return _AlifLetterCard(
                      letter: item,
                      isSelected: _selected?.id == item.id,
                      onTap: () => _playLetter(item),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailHeader(AlifLetter? letter) {
    final isolatedGlyph = letter?.forms.isolated ?? ' ';
    final initialGlyph = letter?.forms.initial ?? ' ';
    final medialGlyph = letter?.forms.medial ?? ' ';
    final finalGlyph = letter?.forms.finalForm ?? ' ';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: Colors.black26,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          children: [
            Text(
              isolatedGlyph,
              style: const TextStyle(color: Colors.deepPurpleAccent, fontSize: 88),
            ),
            const SizedBox(width: 36),
            const Spacer(),
            _formChip('Initial', initialGlyph),
            _formChip('Medial', medialGlyph),
            _formChip('Final', finalGlyph),
          ],
        ),
      ),
    );
  }

  Widget _formChip(String label, String glyph) {
    return Padding(
      padding: const EdgeInsets.only(left: 36),
      child: Column(
        children: [
          Text(
            glyph,
            style: const TextStyle(color: Colors.amber, fontSize: 111),
          ),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }
}


class _AlifGuessSection extends StatefulWidget {
  const _AlifGuessSection();

  @override
  State<_AlifGuessSection> createState() => _AlifGuessSectionState();
}

class _AlifGuessSectionState extends State<_AlifGuessSection> {
  static const int _choiceCount = 12;
  static const Duration _feedbackDuration = Duration(seconds: 3);

  final Random _rand = Random();

  bool _quizActive = false;
  AlifLetter? _target;
  List<AlifLetter> _choices = [];
  bool _locked = false;
  int? _feedbackLetterId;
  bool? _feedbackCorrect;

  List<AlifLetter> get _playableLetters =>
      alifAlphabet.where((l) => l.audioAsset.isNotEmpty).toList();

  void _startQuiz() {
    setState(() => _quizActive = true);
    _startNewRound();
  }

  void _stopQuiz() {
    setState(() {
      _quizActive = false;
      _target = null;
      _choices = [];
      _locked = false;
      _feedbackLetterId = null;
      _feedbackCorrect = null;
    });
  }

  void _startNewRound() {
    final playable = _playableLetters;
    final target = playable[_rand.nextInt(playable.length)];

    final others = List<AlifLetter>.from(playable)..remove(target);
    others.shuffle(_rand);
    final choices = [target, ...others.take(_choiceCount - 1)]..shuffle(_rand);

    setState(() {
      _target = target;
      _choices = choices;
      _locked = false;
      _feedbackLetterId = null;
      _feedbackCorrect = null;
    });

    AlifAudioPlayer.instance.playLetter(target.audioAsset);
  }

  void _replayTarget() {
    if (_target == null) return;
    AlifAudioPlayer.instance.playLetter(_target!.audioAsset);
  }

  void _onChoiceTap(AlifLetter letter) {
    if (_locked || _target == null) return;
    final isCorrect = letter.id == _target!.id;

    setState(() {
      _locked = true;
      _feedbackLetterId = letter.id;
      _feedbackCorrect = isCorrect;
    });

    AlifAudioPlayer.instance.playLetter(letter.audioAsset);

    Future.delayed(_feedbackDuration, () {
      if (!mounted || !_quizActive) return;
      if (isCorrect) {
        _startNewRound();
      } else {
        setState(() {
          _locked = false;
          _feedbackLetterId = null;
          _feedbackCorrect = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: const Text('Guess', style: TextStyle(color: Colors.white)),
        iconColor: Colors.deepPurpleAccent,
        collapsedIconColor: Colors.white54,
        onExpansionChanged: (expanded) {
          if (!expanded) _stopQuiz();
        },
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.play_circle_fill),
                      iconSize: 36,
                      color: _target != null ? Colors.tealAccent : Colors.white24,
                      onPressed: _target != null ? _replayTarget : null,
                      tooltip: 'Replay sound',
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _quizActive ? _stopQuiz : _startQuiz,
                      icon: Icon(_quizActive ? Icons.stop : Icons.play_arrow),
                      label: Text(_quizActive ? 'Stop Quiz' : 'Start Quiz'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _quizActive ? Colors.red[900] : Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_quizActive)
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: _choices.map((letter) {
                        final isFeedback = _feedbackLetterId == letter.id;
                        return _AlifGuessPill(
                          letter: letter,
                          feedbackCorrect: isFeedback ? _feedbackCorrect : null,
                          onTap: _locked ? null : () => _onChoiceTap(letter),
                        );
                      }).toList(),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Press "Start Quiz" to begin.',
                      style: TextStyle(color: Colors.white38),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlifGuessPill extends StatelessWidget {
  final AlifLetter letter;
  final bool? feedbackCorrect;
  final VoidCallback? onTap;

  const _AlifGuessPill({
    required this.letter,
    required this.feedbackCorrect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.black26;
    Color border = Colors.white12;
    if (feedbackCorrect == true) {
      bg = Colors.green.withAlpha(140);
      border = Colors.greenAccent;
    } else if (feedbackCorrect == false) {
      bg = Colors.red.withAlpha(140);
      border = Colors.redAccent;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(72),
          border: Border.all(color: border, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          letter.forms.isolated,
          style: const TextStyle(color: Colors.white, fontSize: 34),
        ),
      ),
    );
  }
}

class _AlifLetterCard extends StatefulWidget {
  final AlifLetter letter;
  final bool isSelected;
  final VoidCallback onTap;
  const _AlifLetterCard({
    required this.letter,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_AlifLetterCard> createState() => _AlifLetterCardState();
}

class _AlifLetterCardState extends State<_AlifLetterCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final letter = widget.letter;
    final hasAudio = letter.audioAsset.isNotEmpty;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.deepPurple.withAlpha(60)
                : (_hovering ? Colors.cyanAccent.withAlpha(20) : Colors.black26),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected ? Colors.deepPurple : Colors.white12,
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                letter.forms.isolated,
                style: TextStyle(
                  color: widget.isSelected ? Colors.deepPurpleAccent : Colors.white,
                  fontSize: 111,
                ),
              ),
              const SizedBox(height: 4),
              if (!hasAudio)
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.volume_off, size: 10, color: Colors.white24),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
