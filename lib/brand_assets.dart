import 'package:flutter/material.dart';

const brainyMarkAsset = 'assets/branding/brainy_mark.png';
const brainyShowcaseAsset = 'assets/branding/brainy_showcase.png';

class BrainyMark extends StatelessWidget {
  const BrainyMark({super.key, this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    brainyMarkAsset,
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
    semanticLabel: 'Brainy',
  );
}
