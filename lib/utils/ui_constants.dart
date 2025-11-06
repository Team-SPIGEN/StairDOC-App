import 'package:flutter/material.dart';

class Insets {
  const Insets._();

  static const double base = 8;
  static const double xs = base;
  static const double sm = base * 2;
  static const double md = base * 3;
  static const double lg = base * 4;
}

class CornerRadius {
  const CornerRadius._();

  static const BorderRadius button = BorderRadius.all(Radius.circular(8));
  static const BorderRadius card = BorderRadius.all(Radius.circular(12));
}
