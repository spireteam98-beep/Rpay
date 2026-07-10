/// Outcome of confirming a card payment via [SplitCardForm].
class CardConfirmResult {
  final bool succeeded;
  final String? paymentIntentId;
  final String? errorMessage;

  const CardConfirmResult.success(this.paymentIntentId)
    : succeeded = true,
      errorMessage = null;
  const CardConfirmResult.failure(this.errorMessage)
    : succeeded = false,
      paymentIntentId = null;
}
