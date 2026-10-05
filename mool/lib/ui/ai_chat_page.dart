import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app/theme.dart';
import '../services/ai_chat_service.dart';
import 'help_page.dart';
import 'widgets/common.dart';

/// Full AI chat screen — "Talk to Mool" inside the mobile app.
/// Powered by Groq (llama-3.3-70b-versatile) via Firebase Cloud Functions.
class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> with TickerProviderStateMixin {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focusNode = FocusNode();
  bool _sending = false;
  late final AnimationController _typingAnim;

  final List<AiMessage> _messages = [
    AiMessage(
      id: 'welcome',
      role: 'assistant',
      text: 'Hello. I am Mool — a quiet space to help you stay grounded. '
          'How are you feeling right now?',
      at: DateTime.now(),
      category: 'Welcome',
    ),
  ];

  static const _quickPrompts = [
    'I had trouble sleeping last night',
    'I feel scared about my court hearing',
    'Can we do a breathing exercise?',
    'I feel alone and no one understands',
    'Someone threatened me today',
  ];

  @override
  void initState() {
    super.initState();
    _typingAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focusNode.dispose();
    _typingAnim.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    Timer(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _sending) return;

    _input.clear();
    _focusNode.unfocus();
    HapticFeedback.lightImpact();

    final userMsg = AiMessage(
      id: 'u-${DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      text: text,
      at: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _sending = true;
    });
    _scrollToBottom();

    try {
      final reply = await AiChatService.instance.sendMessage(text);
      if (!mounted) return;

      setState(() {
        _messages.add(reply);
        _sending = false;
      });
      _scrollToBottom();

      // If crisis detected, show help page
      if (reply.isCrisis) {
        if (!mounted) return;
        unawaited(
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (ctx) => AlertDialog(
              title: const Text('We want you to be safe'),
              content: const Text(
                'It sounds like you may be going through something very difficult. '
                'Would you like to see ways to get help right now?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Not now'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HelpPage()),
                    );
                  },
                  child: const Text('Show me'),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: MoolPalette.moss,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  'M',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Talk to Mool', style: t.titleMedium),
                Text(
                  'Powered by Groq AI • Trauma-Informed',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: MoolPalette.moss,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: const [GetHelpButton()],
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (context, i) {
                // Typing indicator
                if (i == _messages.length && _sending) {
                  return _TypingIndicator(animation: _typingAnim);
                }
                return _ChatBubble(message: _messages[i]);
              },
            ),
          ),

          // Quick prompts (only show when few messages)
          if (_messages.length <= 2)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 14),
              child: SizedBox(
                height: 42,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _quickPrompts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => _QuickPromptChip(
                    text: _quickPrompts[i],
                    onTap: () => _send(_quickPrompts[i]),
                  ),
                ),
              ),
            ),

          // Input area
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 10, 12 + bottomPad),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? const Color(0xFF353C34)
                      : const Color(0xFFE4DFD5),
                  width: 1.1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    focusNode: _focusNode,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    maxLines: 4,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: 'Share what is on your mind...',
                      hintStyle: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      filled: true,
                      fillColor: isDark ? MoolPalette.nightRaised : MoolPalette.linen,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: _sending ? scheme.outlineVariant : MoolPalette.moss,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _sending ? null : () => _send(),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Icons.send_rounded,
                        size: 20,
                        color: _sending ? scheme.onSurfaceVariant : Colors.white,
                      ),
                    ),
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

/// Individual chat message bubble.
class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});
  final AiMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: MoolPalette.moss,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  'M',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? MoolPalette.moss
                    : message.isCrisis
                        ? MoolPalette.signalSoft
                        : (isDark ? MoolPalette.nightRaised : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                border: isUser
                    ? null
                    : message.isCrisis
                        ? Border.all(color: MoolPalette.signal.withValues(alpha: 0.3))
                        : Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category badge
                  if (!isUser && message.category != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.category!.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: message.isCrisis
                              ? MoolPalette.signal
                              : MoolPalette.moss,
                        ),
                      ),
                    ),

                  // Message text
                  Text(
                    message.text,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.5,
                      color: isUser ? Colors.white : scheme.onSurface,
                    ),
                  ),

                  // Sentiment indicator for assistant messages
                  if (!isUser && message.emotion != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _emotionIcon(message.emotion!),
                          size: 12,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Detected: ${message.emotion}',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Crisis action
                  if (message.isCrisis) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: MoolPalette.signal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone_in_talk_rounded, size: 14, color: MoolPalette.signal),
                          const SizedBox(width: 6),
                          Text(
                            'Tap "Get Help" to connect now',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: MoolPalette.signal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Time
                  const SizedBox(height: 4),
                  Text(
                    '${message.at.hour.toString().padLeft(2, '0')}:${message.at.minute.toString().padLeft(2, '0')}',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: isUser
                          ? Colors.white.withValues(alpha: 0.6)
                          : scheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  IconData _emotionIcon(String emotion) => switch (emotion.toLowerCase()) {
        'fear' || 'scared' => Icons.warning_amber_rounded,
        'anger' || 'angry' => Icons.local_fire_department_outlined,
        'sadness' || 'sad' => Icons.water_drop_outlined,
        'anxiety' || 'anxious' => Icons.psychology_outlined,
        'hope' || 'hopeful' => Icons.wb_sunny_outlined,
        'calm' || 'peaceful' => Icons.spa_outlined,
        'distress' => Icons.heart_broken_outlined,
        _ => Icons.circle_outlined,
      };
}

/// Animated typing dots shown while waiting for AI response.
class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.animation});
  final AnimationController animation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: MoolPalette.moss,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                'M',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? MoolPalette.nightRaised : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    _Dot(
                      progress: ((animation.value - i * 0.15) % 1.0).clamp(0.0, 1.0),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Text(
                    'Mool is thinking...',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final bounce = (progress < 0.5 ? progress * 2 : 2 - progress * 2).clamp(0.0, 1.0);
    return Transform.translate(
      offset: Offset(0, -4 * bounce),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: MoolPalette.moss.withValues(alpha: 0.4 + 0.6 * bounce),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _QuickPromptChip extends StatelessWidget {
  const _QuickPromptChip({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF262C25) : const Color(0xFFF6F8F4);
    final border = isDark ? const Color(0xFF3C443A) : const Color(0xFFD4DDD1);
    final fg = isDark ? const Color(0xFFE0E6DE) : const Color(0xFF263325);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}
