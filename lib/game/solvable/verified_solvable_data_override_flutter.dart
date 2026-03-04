import 'package:flutter/foundation.dart';

final ValueNotifier<bool> _ignoreVerifiedSolvableDataNotifier =
    ValueNotifier<bool>(false);

bool get ignoreVerifiedSolvableData =>
    _ignoreVerifiedSolvableDataNotifier.value;

void setIgnoreVerifiedSolvableData(bool value) {
  if (_ignoreVerifiedSolvableDataNotifier.value == value) {
    return;
  }
  _ignoreVerifiedSolvableDataNotifier.value = value;
}
