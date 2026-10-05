import React, { useState, useRef, useEffect } from 'react';
import { Send, Bot, User, ShieldAlert, Sparkles, Loader2, Mic, MicOff, Brain, Heart } from 'lucide-react';
import { GroundedCard } from '../common/GroundedCard';
import { OrganicButton } from '../common/OrganicButton';
import { getAiChatResponse, AiChatMessage } from '../../services/aiService';

interface ChatMessage {
  id: string;
  sender: 'user' | 'mool';
  text: string;
  timestamp: string;
  isAcuteCrisis?: boolean;
  category?: string;
  sentiment?: number;
  emotion?: string;
}

interface TalkToMoolProps {
  onOpenHelpModal: () => void;
}

export const TalkToMool: React.FC<TalkToMoolProps> = ({ onOpenHelpModal }) => {
  const [messages, setMessages] = useState<ChatMessage[]>([
    {
      id: 'm-1',
      sender: 'mool',
      text: 'Hello. I am Mool — a quiet space to help you stay grounded. How is your mind and body feeling right now?',
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      category: 'Welcome',
    },
  ]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const [conversationHistory, setConversationHistory] = useState<AiChatMessage[]>([]);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages, loading]);

  const handleSend = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!input.trim() || loading) return;

    const userText = input.trim();
    setInput('');

    const userMsg: ChatMessage = {
      id: `u-${Date.now()}`,
      sender: 'user',
      text: userText,
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
    };

    setMessages(prev => [...prev, userMsg]);
    setLoading(true);

    // Add to conversation history for context
    const updatedHistory: AiChatMessage[] = [
      ...conversationHistory,
      { role: 'user' as const, content: userText },
    ];

    try {
      // Call Groq-powered AI service
      const response = await getAiChatResponse(userText, updatedHistory);

      const moolMsg: ChatMessage = {
        id: `m-${Date.now()}`,
        sender: 'mool',
        text: response.text,
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        isAcuteCrisis: response.isAcuteCrisis,
        category: response.category,
        sentiment: response.sentiment,
        emotion: response.emotion,
      };

      setMessages(prev => [...prev, moolMsg]);
      setConversationHistory([
        ...updatedHistory,
        { role: 'assistant' as const, content: response.text },
      ]);

      // Immediate Non-negotiable Acute Crisis Safety Trigger
      if (response.isAcuteCrisis) {
        onOpenHelpModal();
      }
    } catch (err) {
      setMessages(prev => [
        ...prev,
        {
          id: `m-${Date.now()}`,
          sender: 'mool',
          text: 'I am here listening quietly. If you ever feel in danger or need immediate human connection, tap "Get Help Now" anytime.',
          timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        },
      ]);
    } finally {
      setLoading(false);
    }
  };

  const handlePromptClick = (prompt: string) => {
    setInput(prompt);
  };

  const suggestedPrompts = [
    'I am having trouble sleeping tonight',
    'I feel overwhelmed by past memories',
    'Can we do a 1-minute grounding reflection?',
    'I feel scared about my court hearing',
    'Someone has been threatening my family',
  ];

  const getEmotionEmoji = (emotion?: string) => {
    switch (emotion?.toLowerCase()) {
      case 'fear': case 'scared': return '😰';
      case 'anger': case 'angry': return '😤';
      case 'sadness': case 'sad': return '😢';
      case 'anxiety': case 'anxious': return '😟';
      case 'hope': case 'hopeful': return '🌱';
      case 'calm': case 'peaceful': return '🌿';
      case 'distress': return '💔';
      default: return null;
    }
  };

  const getSentimentColor = (sentiment?: number) => {
    if (sentiment == null) return '';
    if (sentiment < -0.5) return 'text-mool-signal';
    if (sentiment < 0) return 'text-mool-sandrose';
    if (sentiment > 0.3) return 'text-mool-moss';
    return 'text-mool-ink-muted';
  };

  return (
    <div className="max-w-md mx-auto h-[calc(100vh-8.5rem)] flex flex-col p-4 pb-20">
      {/* Header Info */}
      <div className="flex items-center justify-between pb-3 border-b border-mool-mist">
        <div className="flex items-center space-x-2">
          <div className="w-8 h-8 rounded-full bg-mool-moss text-white flex items-center justify-center font-serif font-bold text-sm">
            M
          </div>
          <div>
            <h2 className="font-serif text-sm font-semibold text-mool-ink">Talk to Mool</h2>
            <p className="text-[10px] text-mool-moss font-medium">Groq AI • llama-3.3-70b • Trauma-Informed</p>
          </div>
        </div>

        <div className="flex items-center space-x-1.5">
          <div className="flex items-center space-x-1 text-[11px] text-mool-ink-muted bg-mool-mist/40 px-2.5 py-1 rounded-full">
            <Brain className="w-3 h-3 text-mool-dusk" />
            <span>Sentiment AI</span>
          </div>
          <div className="flex items-center space-x-1 text-[11px] text-mool-ink-muted bg-mool-mist/40 px-2.5 py-1 rounded-full">
            <Sparkles className="w-3 h-3 text-mool-sandrose" />
            <span>Explainable</span>
          </div>
        </div>
      </div>

      {/* Message History Container */}
      <div className="flex-1 overflow-y-auto py-4 space-y-3 pr-1">
        {messages.map((msg) => (
          <div
            key={msg.id}
            className={`flex ${msg.sender === 'user' ? 'justify-end' : 'justify-start'}`}
          >
            <div className={`max-w-[85%] rounded-organic-lg p-3.5 text-xs leading-relaxed ${
              msg.sender === 'user'
                ? 'bg-mool-moss text-white rounded-br-none shadow-sm'
                : msg.isAcuteCrisis
                ? 'bg-mool-signal-soft border border-mool-signal/30 text-mool-ink rounded-bl-none'
                : 'bg-white border border-mool-mist text-mool-ink rounded-bl-none shadow-soft-ground'
            }`}>
              {/* Category & Emotion badges */}
              {msg.sender === 'mool' && (msg.category || msg.emotion) && (
                <div className="flex items-center space-x-2 mb-1.5">
                  {msg.category && (
                    <span className="text-[10px] uppercase font-semibold text-mool-moss tracking-wide">
                      {msg.category}
                    </span>
                  )}
                  {msg.emotion && getEmotionEmoji(msg.emotion) && (
                    <span className="text-[10px] bg-mool-mist/50 px-1.5 py-0.5 rounded-full">
                      {getEmotionEmoji(msg.emotion)} {msg.emotion}
                    </span>
                  )}
                </div>
              )}

              <p className="whitespace-pre-wrap">{msg.text}</p>

              {/* Sentiment indicator */}
              {msg.sender === 'mool' && msg.sentiment != null && (
                <div className="mt-1.5 flex items-center space-x-1">
                  <Heart className={`w-3 h-3 ${getSentimentColor(msg.sentiment)}`} />
                  <span className={`text-[9px] ${getSentimentColor(msg.sentiment)}`}>
                    Detected sentiment: {msg.sentiment > 0.3 ? 'positive' : msg.sentiment < -0.3 ? 'distressed' : 'neutral'}
                  </span>
                </div>
              )}

              {msg.isAcuteCrisis && (
                <div className="mt-2 pt-2 border-t border-mool-signal/20">
                  <button
                    onClick={onOpenHelpModal}
                    className="inline-flex items-center space-x-1.5 text-xs font-bold text-mool-signal underline"
                  >
                    <ShieldAlert className="w-4 h-4" />
                    <span>Connect with Emergency Crisis Support Now</span>
                  </button>
                </div>
              )}

              <span className={`text-[9px] block text-right mt-1.5 ${
                msg.sender === 'user' ? 'text-white/70' : 'text-mool-ink-faint'
              }`}>
                {msg.timestamp}
              </span>
            </div>
          </div>
        ))}

        {loading && (
          <div className="flex justify-start">
            <div className="bg-white border border-mool-mist rounded-organic-lg p-3 text-xs text-mool-ink-muted flex items-center space-x-2">
              <Loader2 className="w-4 h-4 text-mool-moss animate-spin" />
              <span>Mool is thinking with Groq AI...</span>
            </div>
          </div>
        )}
        <div ref={messagesEndRef} />
      </div>

      {/* Suggested Grounding Prompts */}
      <div className="pt-2 pb-3 mb-1 flex space-x-2 overflow-x-auto no-scrollbar">
        {suggestedPrompts.map((p, idx) => (
          <button
            key={idx}
            onClick={() => handlePromptClick(p)}
            className="text-[11px] bg-white hover:bg-mool-mist/50 border border-mool-mist text-mool-ink-muted px-3 py-1.5 rounded-full whitespace-nowrap shrink-0 transition-colors shadow-sm"
          >
            {p}
          </button>
        ))}
      </div>

      {/* Input Form */}
      <form onSubmit={handleSend} className="flex items-center space-x-2 pt-2 border-t border-mool-mist/60">
        <input
          type="text"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          placeholder="Share your thoughts gently..."
          className="flex-1 px-4 py-2.5 bg-white border border-mool-mist rounded-full text-xs text-mool-ink focus:border-mool-moss focus:ring-1 focus:ring-mool-moss shadow-sm"
        />
        <OrganicButton type="submit" variant="moss" size="sm" disabled={!input.trim() || loading} className="rounded-full !px-3.5">
          <Send className="w-4 h-4" />
        </OrganicButton>
      </form>

      {/* AI Model Info Footer */}
      <div className="text-center pt-2">
        <p className="text-[9px] text-mool-ink-faint">
          Powered by Groq • llama-3.3-70b-versatile • Sentiment by llama-3.1-8b-instant • Privacy-first
        </p>
      </div>
    </div>
  );
};
