/// A business rule was broken. [message] is safe to show to the user.
/// Services throw a type that implements this. Dialogs catch this type.
abstract interface class RuleViolation implements Exception {
  String get message;
}
