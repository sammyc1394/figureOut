import 'package:figureout/src/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HowToPlayOverlay extends StatefulWidget {
  /// Called when the user dismisses the overlay. [dontShowAgain] is true when
  /// the "Don't show again" checkbox was ticked.
  final ValueChanged<bool> onContinue;

  const HowToPlayOverlay({super.key, required this.onContinue});

  @override
  State<HowToPlayOverlay> createState() => _HowToPlayOverlayState();
}

class _HowToPlayOverlayState extends State<HowToPlayOverlay> {
  bool _dontShowAgain = false;

  static const _items = [
    ('assets/Circle_basic.svg', 'Tap to pop'),
    ('assets/Triangle_basic.svg', 'Trap to pop'),
    ('assets/Rectangle_basic.svg', 'Slice to pop'),
    ('assets/Pentagon_basic.svg', 'Hold to pop'),
    ('assets/Hexagon_basic.svg', 'Stretch to pop'),
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final iconSize = screenWidth * 0.11;
    final fontSize = screenWidth * 0.048;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onContinue(_dontShowAgain),
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.65),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final item in _items) ...[
                      _HowToPlayRow(
                        svgPath: item.$1,
                        label: item.$2,
                        iconSize: iconSize,
                        fontSize: fontSize,
                      ),
                      SizedBox(height: screenWidth * 0.045),
                    ],
                  ],
                ),
              ),
              const Spacer(flex: 2),
              _DontShowAgainCheckbox(
                checked: _dontShowAgain,
                fontSize: fontSize,
                spacing: screenWidth * 0.025,
                onToggle: () =>
                    setState(() => _dontShowAgain = !_dontShowAgain),
              ),
              SizedBox(height: screenWidth * 0.05),
              Text(
                'Click to continue',
                style: TextStyle(
                  fontFamily: appFontFamily,
                  fontSize: fontSize * 0.95,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  decoration: TextDecoration.none,
                ),
              ),
              SizedBox(height: screenWidth * 0.12),
            ],
          ),
        ),
      ),
    );
  }
}

class _DontShowAgainCheckbox extends StatelessWidget {
  final bool checked;
  final double fontSize;
  final double spacing;
  final VoidCallback onToggle;

  const _DontShowAgainCheckbox({
    required this.checked,
    required this.fontSize,
    required this.spacing,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            checked ? Icons.check_box : Icons.check_box_outline_blank,
            color: Colors.white,
            size: fontSize * 1.2,
          ),
          SizedBox(width: spacing),
          Text(
            "Don't show again",
            style: TextStyle(
              fontFamily: appFontFamily,
              fontSize: fontSize * 0.85,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _HowToPlayRow extends StatelessWidget {
  final String svgPath;
  final String label;
  final double iconSize;
  final double fontSize;

  const _HowToPlayRow({
    required this.svgPath,
    required this.label,
    required this.iconSize,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: iconSize,
          height: iconSize,
          child: SvgPicture.asset(svgPath, fit: BoxFit.contain),
        ),
        SizedBox(width: iconSize * 0.35),
        Text(
          '-',
          style: TextStyle(
            fontFamily: appFontFamily,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            decoration: TextDecoration.none,
          ),
        ),
        SizedBox(width: iconSize * 0.35),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: appFontFamily,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }
}
