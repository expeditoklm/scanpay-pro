/// plan_quota.dart
/// Gestion locale des quotas produits par plan.
/// Source de vérité : même valeurs que le .env backend.

const Map<String, int> kPlanProductLimits = {
  'free':       10,
  'basic':      100,
  'pro':        1000,
  'enterprise': 999999,
};

/// Retourne la limite produits pour un plan donné.
int productLimitForPlan(String plan) {
  return kPlanProductLimits[plan.toLowerCase()] ?? 10;
}

/// Résultat d'un contrôle de quota avant ajout.
class QuotaCheckResult {
  const QuotaCheckResult({
    required this.allowed,
    required this.currentCount,
    required this.limit,
    required this.plan,
    this.wouldExceedBy = 0,
  });

  /// L'opération est autorisée
  final bool allowed;
  /// Nb de produits actuellement (serveur + offline)
  final int currentCount;
  /// Limite du plan
  final int limit;
  /// Nom du plan
  final String plan;
  /// De combien on dépasse (0 si allowed)
  final int wouldExceedBy;

  /// Texte du message d'erreur à afficher dans l'UI
  String get errorMessage {
    if (allowed) return '';
    final planLabel = plan[0].toUpperCase() + plan.substring(1);
    return 'Limite atteinte — Plan $planLabel : $limit produits maximum.\n'
        'Vous avez déjà $currentCount produit${currentCount > 1 ? 's' : ''}.'
        '${wouldExceedBy > 0 ? '\nCet import dépasserait la limite de $wouldExceedBy produit${wouldExceedBy > 1 ? 's' : ''}.' : ''}\n'
        'Passez à un plan supérieur pour continuer.';
  }
}

/// Vérifie si on peut ajouter [toAdd] produits supplémentaires.
/// [existingCount] = nb total actuel (serveur + offline pending).
QuotaCheckResult checkProductQuota({
  required String plan,
  required int existingCount,
  int toAdd = 1,
}) {
  final limit = productLimitForPlan(plan);
  final afterAdd = existingCount + toAdd;
  final allowed = afterAdd <= limit;
  return QuotaCheckResult(
    allowed: allowed,
    currentCount: existingCount,
    limit: limit,
    plan: plan,
    wouldExceedBy: allowed ? 0 : afterAdd - limit,
  );
}