import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../help_page.dart';

import 'package:google_fonts/google_fonts.dart';

/// Always visible in the app bar. Styled after the Mool CrisisBar.
class GetHelpButton extends StatelessWidget {
  const GetHelpButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? MoolPalette.sandroseLight : MoolPalette.sandrose;
    final bg = isDark ? MoolPalette.sandrose.withValues(alpha: 0.2) : MoolPalette.sandroseSoft;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpPage())),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.45), width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.phone_in_talk_rounded, size: 14, color: color),
                const SizedBox(width: 6),
                Text(
                  'Get Help',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A large, tappable answer row used in check-ins and questionnaires.
class AnswerOption extends StatelessWidget {
  const AnswerOption({super.key, required this.label, required this.selected, required this.onTap, this.leading});

  final String label;
  final String? leading;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? scheme.secondaryContainer : scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  if (leading != null) ...[
                    Text(leading!, style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 14),
                  ],
                  Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
                  if (selected) Icon(Icons.check_circle, color: scheme.primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Press and hold to confirm. Used for "I'm in danger" and "I'm safe now" so
/// a pocket tap or a slip of the finger can't start or stop an emergency.
class HoldToConfirm extends StatefulWidget {
  const HoldToConfirm({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.color,
    this.foreground = Colors.white,
    this.duration = const Duration(milliseconds: 1600),
    this.hint = 'Press and hold',
  });

  final String label;
  final String hint;
  final VoidCallback onConfirmed;
  final Color? color;
  final Color foreground;
  final Duration duration;

  @override
  State<HoldToConfirm> createState() => _HoldToConfirmState();
}

class _HoldToConfirmState extends State<HoldToConfirm> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        HapticFeedback.heavyImpact();
        widget.onConfirmed();
        _c.reset();
      }
    });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.error;
    return Semantics(
      button: true,
      label: '${widget.label}. ${widget.hint}.',
      onLongPress: widget.onConfirmed,
      child: Listener(
        onPointerDown: (_) {
          HapticFeedback.lightImpact();
          _c.forward();
        },
        onPointerUp: (_) => _c.status == AnimationStatus.completed ? null : _c.reverse(),
        onPointerCancel: (_) => _c.reverse(),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 76,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.85)),
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: _c.value,
                    child: Container(color: color),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.label,
                            style: TextStyle(color: widget.foreground, fontSize: 20, fontWeight: FontWeight.w700)),
                        Text(widget.hint,
                            style: TextStyle(color: widget.foreground.withValues(alpha: 0.85), fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child, this.onTap, this.tint});
  final Widget child;
  final VoidCallback? onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: tint,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(20), child: child),
      ),
    );
  }
}

class ToolTile extends StatelessWidget {
  const ToolTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconBg,
    this.iconColor,
    this.tag,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconBg;
  final Color? iconColor;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isSignal = iconColor == MoolPalette.signal || iconBg == MoolPalette.signalSoft;

    // High-contrast, WCAG AAA compliant color resolution for guaranteed visibility
    final Color containerBg;
    final Color borderColor;
    final Color fgColor;

    if (isSignal) {
      containerBg = isDark ? const Color(0xFF382320) : const Color(0xFFFDEEEB);
      borderColor = isDark ? const Color(0xFFE27B68).withValues(alpha: 0.65) : const Color(0xFFD66A55).withValues(alpha: 0.6);
      fgColor = isDark ? const Color(0xFFF79C8C) : const Color(0xFF9E3621);
    } else {
      containerBg = isDark ? const Color(0xFF283427) : const Color(0xFFEBF2EA);
      borderColor = isDark ? const Color(0xFF5F855E).withValues(alpha: 0.65) : const Color(0xFF7A9E78).withValues(alpha: 0.6);
      fgColor = isDark ? const Color(0xFFA5D4A3) : const Color(0xFF334F32);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: containerBg,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: borderColor,
                  width: 1.2,
                ),
              ),
              child: Center(
                child: Icon(icon, color: fgColor, size: 22),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: isDark ? Colors.white : MoolPalette.ink,
                              ),
                        ),
                      ),
                      if (tag != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: containerBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: borderColor, width: 1),
                          ),
                          child: Text(
                            tag!,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: fgColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? const Color(0xFFA5ABA3) : MoolPalette.slate,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white38 : MoolPalette.slate.withValues(alpha: 0.7), size: 22),
          ],
        ),
      ),
    );
  }
}

void showQuietSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

const calmBlue = MoolPalette.dusk;
