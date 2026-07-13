import 'package:flutter/foundation.dart';

@immutable
class ActiveSwap {
  const ActiveSwap({required this.firstBookId, required this.secondBookId});

  final String firstBookId;
  final String secondBookId;
}
