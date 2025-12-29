import 'package:flutter/material.dart';

// Karnataka flag inspired colors and a reusable gradient background.
const Color kKarnatakaFlagYellow = Color(0xFFFFCD00);
const Color kKarnatakaFlagRed = Color(0xFFC8102E);

class KarnatakaGradient extends StatelessWidget {
  final Widget child;
  final Alignment begin;
  final Alignment end;
  const KarnatakaGradient({super.key, required this.child, this.begin = Alignment.topCenter, this.end = Alignment.bottomCenter});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kKarnatakaFlagYellow, kKarnatakaFlagRed],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: child,
    );
  }
}
