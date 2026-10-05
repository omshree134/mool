import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'text_signals.dart';

/// A single message in the AI chat.
class AiMessage {
  AiMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.at,
    this.sentiment,
    this.emotion,
    this.isCrisis = false,
    this.category,
  });

  final String id;
  final String role; // 'user' | 'assistant'
  final String text;
  final DateTime at;
  final double? sentiment; // -1 (very negative) to 1 (very positive)
  final String? emotion; // anger, fear, sadness, anxiety, hope, calm, neutral
  final bool isCrisis;
  final String? category;

  Map<String, dynamic> toMap() => {
        'id': id,
        'role': role,
        'text': text,
        'at': at.toIso8601String(),
        'sentiment': sentiment,
        'emotion': emotion,
        'isCrisis': isCrisis,
        'category': category,
      };

  factory AiMessage.fromMap(Map<String, dynamic> m) => AiMessage(
        id: m['id'] as String,
        role: m['role'] as String,
        text: m['text'] as String,
        at: DateTime.parse(m['at'] as String),
        sentiment: (m['sentiment'] as num?)?.toDouble(),
        emotion: m['emotion'] as String?,
        isCrisis: m['isCrisis'] as bool? ?? false,
        category: m['category'] as String?,
      );
}

/// Result of a sentiment analysis call.
class SentimentResult {
  SentimentResult({
    required this.score,
    required this.emotion,
    required this.distressIndicators,
  });

  /// -1.0 (very negative) to 1.0 (very positive)
  final double score;

  /// Primary detected emotion
  final String emotion;

  /// Specific distress signals found
  final List<String> distressIndicators;
}

/// Service that manages AI conversations using Groq API
/// (proxied through Firebase Cloud Functions or called directly via Groq API).
///
/// Models used:
///   - llama-3.3-70b-versatile  → main conversation
///   - llama-3.1-8b-instant     → fast sentiment analysis
///   - whisper-large-v3         → voice transcription (future)
class AiChatService {
  AiChatService._();
  static final AiChatService instance = AiChatService._();

  static const _groqApiUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const _envGroqApiKey = String.fromEnvironment('GROQ_API_KEY');
  static const _defaultGroqApiKey = '';
  static const _workerProxyUrl = String.fromEnvironment(
    'MOOL_API_URL',
    defaultValue: 'https://mool-worker.omshreechoudhary7.workers.dev',
  );

  /// Primary chat model on Groq
  static const defaultChatModel = 'qwen/qwen3.8-27b';
  /// Fast sentiment model on Groq
  static const defaultFastModel = 'qwen/qwen3.8-27b';

  /// Optional runtime override for Groq API key
  String? customApiKey;
  String get _activeApiKey {
    if (customApiKey != null && customApiKey!.isNotEmpty) return customApiKey!;
    if (_envGroqApiKey.isNotEmpty) return _envGroqApiKey;
    return _defaultGroqApiKey;
  }

  final _functions = FirebaseFunctions.instanceFor(region: 'asia-south1');

  final List<AiMessage> _history = [];
  List<AiMessage> get history => List.unmodifiable(_history);

  /// Cloudflare Worker edge proxy client.
  Future<String?> _callWorkerProxy(List<Map<String, String>> messages, {String lang = 'hi'}) async {
    try {
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse('$_workerProxyUrl/ai/chat'));
      request.headers.set('Content-Type', 'application/json');
      request.add(utf8.encode(jsonEncode({
        'messages': messages,
        'lang': lang,
      })));
      final response = await request.close().timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final map = jsonDecode(body) as Map<String, dynamic>;
        return map['content'] as String?;
      }
    } catch (_) {
      // Fall through to direct Groq client
    }
    return null;
  }

  /// Direct Groq API client using native HttpClient with candidate fallback.
  Future<String?> _callGroqDirect(
    List<Map<String, String>> messages, {
    String model = defaultChatModel,
    double temperature = 0.7,
    int maxTokens = 512,
  }) async {
    final apiKey = _activeApiKey;
    if (apiKey.isEmpty) return null;

    final candidateModels = <String>{
      model,
      'qwen/qwen3.8-27b',
      'openai/gpt-oss-120b',
      'openai/gpt-oss-20b',
    }.toList();

    final client = HttpClient();
    try {
      for (final candidate in candidateModels) {
        try {
          final request = await client.postUrl(Uri.parse(_groqApiUrl));
          request.headers.set('Authorization', 'Bearer $apiKey');
          request.headers.set('Content-Type', 'application/json');
          request.add(utf8.encode(jsonEncode({
            'messages': messages,
            'model': candidate,
            'temperature': temperature,
            'max_tokens': maxTokens,
          })));
          final response = await request.close();
          if (response.statusCode == 200) {
            final body = await response.transform(utf8.decoder).join();
            final map = jsonDecode(body) as Map<String, dynamic>;
            final choices = map['choices'] as List?;
            if (choices != null && choices.isNotEmpty) {
              final content = choices[0]['message']?['content'] as String?;
              if (content != null && content.trim().isNotEmpty) {
                return content;
              }
            }
          } else {
            final err = await response.transform(utf8.decoder).join();
            debugPrint('Direct Groq error on $candidate (${response.statusCode}): $err');
          }
        } catch (e) {
          debugPrint('Direct Groq candidate $candidate error: $e');
        }
      }
    } catch (e) {
      debugPrint('Direct Groq call error: $e');
    } finally {
      client.close();
    }
    return null;
  }

  /// The system prompt that grounds the AI as a trauma-informed companion.
  static const systemPrompt = '''You are Mool (मूल), a trauma-informed mental health companion for victims of atrocities registered under the SC/ST Prevention of Atrocities Act, 1989 in India.

CORE PRINCIPLES:
- You are warm, patient, and deeply empathetic
- You speak simply and gently, avoiding clinical jargon
- You support in Hindi, English, and Hinglish naturally based on the user's language
- You NEVER diagnose, prescribe medication, or replace professional help
- You are a grounding presence, not a therapist

WHAT YOU DO:
- Help with grounding exercises (5-4-3-2-1, box breathing, body scan)
- Validate feelings without judgment
- Gently explore how they are feeling today
- Recognize signs of distress and suggest connecting with their counsellor
- Support through court hearing anxiety, intimidation fears, isolation
- Offer culturally sensitive coping techniques
- Remind them of their safety plan if they have one

SAFETY RULES:
- If someone expresses thoughts of self-harm or suicide, respond with empathy and immediately recommend connecting with their crisis helpline or counsellor
- Never minimize their experiences of caste-based violence or discrimination
- Always respect their pace — never push them to share more than they want
- Remind them that what happened was NOT their fault

CONTEXT:
- These are victims who may face threats, intimidation, repeated court appearances, social ostracism, economic hardship
- Many are from rural areas with limited access to mental health services
- The app provides daily check-ins, safety plans, and emergency SOS features
- Their guardians (counsellors/family) can see anonymized wellbeing trends

Keep responses concise (2-4 sentences usually). Be human, not robotic.''';

  /// Send a message and get an AI response.
  /// Returns the assistant's reply message.
  Future<AiMessage> sendMessage(String userText) async {
    final trimmed = userText.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Message cannot be empty');
    }

    // 1. Check for crisis language deterministically (on-device, no AI needed)
    final isCrisis = TextSignals.mightExpressCrisis(trimmed);

    // 2. Add user message to history
    final userMsg = AiMessage(
      id: 'u-${DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      text: trimmed,
      at: DateTime.now(),
      isCrisis: isCrisis,
    );
    _history.add(userMsg);

    // 3. If crisis, return immediate safety response without waiting for AI
    if (isCrisis) {
      final crisisReply = AiMessage(
        id: 'm-${DateTime.now().millisecondsSinceEpoch}',
        role: 'assistant',
        text: 'I hear how much pain you are in right now. Your safety matters '
            'more than anything else. Please reach out to your counsellor or '
            'call the crisis helpline — they are ready to support you without '
            'judgment. You can tap "Get Help" at the top of your screen '
            'to connect right now.',
        at: DateTime.now(),
        isCrisis: true,
        category: 'Crisis Safety',
        sentiment: -0.9,
        emotion: 'distress',
      );
      _history.add(crisisReply);
      return crisisReply;
    }

    // 4. Build conversation context (last 10 messages for token efficiency)
    final contextMessages = _history
        .where((m) => m.role == 'user' || m.role == 'assistant')
        .toList();
    final recent = contextMessages.length > 10
        ? contextMessages.sublist(contextMessages.length - 10)
        : contextMessages;

    final messages = [
      {'role': 'system', 'content': systemPrompt},
      for (final m in recent) {'role': m.role, 'content': m.text},
    ];

    // 5. Try Cloudflare Edge Worker Proxy first (instant edge execution, trauma prompts, crisis check)
    final workerReply = await _callWorkerProxy(messages);
    if (workerReply != null && workerReply.trim().isNotEmpty) {
      final aiMsg = AiMessage(
        id: 'm-${DateTime.now().millisecondsSinceEpoch}',
        role: 'assistant',
        text: workerReply.trim(),
        at: DateTime.now(),
        category: 'AI Companion',
      );
      _history.add(aiMsg);
      return aiMsg;
    }

    // 6. Direct Groq API client fallback (if offline or worker unreachable)
    if (_activeApiKey.isNotEmpty) {
      final directReply = await _callGroqDirect(
        messages,
        model: defaultChatModel,
        temperature: 0.7,
        maxTokens: 512,
      );

      if (directReply != null && directReply.trim().isNotEmpty) {
        final aiMsg = AiMessage(
          id: 'm-${DateTime.now().millisecondsSinceEpoch}',
          role: 'assistant',
          text: directReply.trim(),
          at: DateTime.now(),
          category: 'AI Companion',
        );
        _history.add(aiMsg);
        return aiMsg;
      }
    }

    // 6. Secondary fallback: Firebase Cloud Function (if deployed)
    try {
      final callable = _functions.httpsCallable(
        'groqChat',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 8)),
      );

      final result = await callable.call<Map<String, dynamic>>({
        'messages': messages,
        'model': defaultChatModel,
        'temperature': 0.7,
        'max_tokens': 512,
      });

      final data = result.data;
      final replyText = data['reply'] as String?;
      if (replyText != null && replyText.trim().isNotEmpty) {
        final aiMsg = AiMessage(
          id: 'm-${DateTime.now().millisecondsSinceEpoch}',
          role: 'assistant',
          text: replyText.trim(),
          at: DateTime.now(),
          sentiment: (data['sentiment'] as num?)?.toDouble(),
          emotion: data['emotion'] as String?,
          category: data['category'] as String?,
        );
        _history.add(aiMsg);
        return aiMsg;
      }
    } catch (e) {
      debugPrint('Cloud Function groqChat failed: $e');
    }

    // 7. Final fallback: grounded compassionate response
    final fallback = AiMessage(
      id: 'm-${DateTime.now().millisecondsSinceEpoch}',
      role: 'assistant',
      text: _fallbackResponse(),
      at: DateTime.now(),
      category: 'General Grounding',
    );
    _history.add(fallback);
    return fallback;
  }

  /// Analyze sentiment of text using the fast model.
  /// Used by the distress engine to score check-in notes.
  Future<SentimentResult> analyzeSentiment(String text) async {
    // 1. Try direct Groq API
    if (_activeApiKey.isNotEmpty) {
      final directJson = await _callGroqDirect([
        {
          'role': 'system',
          'content': 'Analyze clinical sentiment for a trauma victim check-in note. Output ONLY JSON: {"score": <number -1.0 to 1.0>, "emotion": "<anger|fear|sadness|anxiety|hope|calm|neutral>", "indicators": []}'
        },
        {'role': 'user', 'content': text}
      ], model: defaultFastModel, temperature: 0.1, maxTokens: 128);

      if (directJson != null) {
        try {
          final match = RegExp(r'\{[\s\S]*\}').firstMatch(directJson);
          if (match != null) {
            final parsed = jsonDecode(match.group(0)!) as Map<String, dynamic>;
            return SentimentResult(
              score: (parsed['score'] as num?)?.toDouble() ?? 0.0,
              emotion: parsed['emotion'] as String? ?? 'neutral',
              distressIndicators: List<String>.from(parsed['indicators'] ?? []),
            );
          }
        } catch (e) {
          debugPrint('Direct sentiment JSON parse error: $e');
        }
      }
    }

    // 2. Secondary fallback: Cloud Function (if deployed)
    try {
      final callable = _functions.httpsCallable(
        'groqSentiment',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 6)),
      );

      final result = await callable.call<Map<String, dynamic>>({
        'text': text,
        'model': defaultFastModel,
      });

      final data = result.data;
      return SentimentResult(
        score: (data['score'] as num?)?.toDouble() ?? 0.0,
        emotion: data['emotion'] as String? ?? 'neutral',
        distressIndicators: List<String>.from(data['indicators'] ?? []),
      );
    } catch (e) {
      debugPrint('Cloud Function groqSentiment failed: $e');
    }

    // 3. Final fallback to on-device lexicon analysis
    final negativity = TextSignals.negativity(text);
    return SentimentResult(
      score: negativity == null ? 0.0 : -(negativity * 2 - 1),
      emotion: 'neutral',
      distressIndicators: [],
    );
  }

  /// Clear conversation history (e.g., when starting a new session).
  void clearHistory() {
    _history.clear();
  }

  String _fallbackResponse() =>
      'I am here listening quietly. Whatever you are feeling right now is '
      'valid and understandable. Would you like to try a short grounding '
      'exercise together, or just talk about how your day has been?';
}
