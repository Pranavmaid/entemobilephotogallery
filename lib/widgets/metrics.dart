import 'package:flutter/material.dart';

class Metrics {
  final double scale;
  final double gap;
  final double tileRadius;
  final double headerExtent;
  final double headerPadTop;
  final double headerPadBottom;
  final double headerHGutter;
  final double labelFs;
  final double subFs;
  final double topBarPadH;
  final double topBarPadTop;
  final double topBarPadBottom;
  final double titleFs;
  final double titleSubFs;
  final double modeIconSize;
  final double modePadH;
  final double modePadV;
  final double modeRadius;
  final double modeOuterRadius;
  final double topIconSize;
  final double topIconGap;
  final double indicatorPadH;
  final double indicatorPadV;
  final double indicatorIconSize;
  final double indicatorBigFs;
  final double indicatorSmallFs;
  final double indicatorGap;
  final double selBarPadH;
  final double selBarPadTop;
  final double selBarBtnPadH;
  final double selBarIconSize;
  final double selBarLabelFs;
  final double selBarReserved;

  const Metrics._({
    required this.scale,
    required this.gap,
    required this.tileRadius,
    required this.headerExtent,
    required this.headerPadTop,
    required this.headerPadBottom,
    required this.headerHGutter,
    required this.labelFs,
    required this.subFs,
    required this.topBarPadH,
    required this.topBarPadTop,
    required this.topBarPadBottom,
    required this.titleFs,
    required this.titleSubFs,
    required this.modeIconSize,
    required this.modePadH,
    required this.modePadV,
    required this.modeRadius,
    required this.modeOuterRadius,
    required this.topIconSize,
    required this.topIconGap,
    required this.indicatorPadH,
    required this.indicatorPadV,
    required this.indicatorIconSize,
    required this.indicatorBigFs,
    required this.indicatorSmallFs,
    required this.indicatorGap,
    required this.selBarPadH,
    required this.selBarPadTop,
    required this.selBarBtnPadH,
    required this.selBarIconSize,
    required this.selBarLabelFs,
    required this.selBarReserved,
  });

  factory Metrics.of(BuildContext ctx) {
    final mq = MediaQuery.of(ctx);
    final shortest = mq.size.shortestSide;
    final s = (shortest / 390.0).clamp(0.82, 1.6);
    final tabletBoost = shortest >= 600 ? 1.15 : 1.0;
    return Metrics._(
      scale: s.toDouble(),
      gap: 3 * s,
      tileRadius: 6 * s,
      headerExtent: 64 * s,
      headerPadTop: 14 * s,
      headerPadBottom: 8 * s,
      headerHGutter: 14 * s,
      labelFs: 17 * s,
      subFs: 12 * s,
      topBarPadH: 14 * s,
      topBarPadTop: 12 * s,
      topBarPadBottom: 8 * s,
      titleFs: 26 * s * tabletBoost,
      titleSubFs: 11 * s,
      modeIconSize: 16 * s,
      modePadH: 8 * s,
      modePadV: 4 * s,
      modeRadius: 12 * s,
      modeOuterRadius: 14 * s,
      topIconSize: 22 * s,
      topIconGap: 6 * s,
      indicatorPadH: 22 * s,
      indicatorPadV: 12 * s,
      indicatorIconSize: 18 * s,
      indicatorBigFs: 22 * s,
      indicatorSmallFs: 11 * s,
      indicatorGap: 8 * s,
      selBarPadH: 12 * s,
      selBarPadTop: 12 * s,
      selBarBtnPadH: 12 * s,
      selBarIconSize: 22 * s,
      selBarLabelFs: 10 * s,
      selBarReserved: 110 * s,
    );
  }
}
