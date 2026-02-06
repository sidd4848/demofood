import 'profile_service.dart';

enum PlanTier { free, trial, pro, elite }

PlanTier resolvePlanTier(SubscriptionSummary? summary) {
  if (summary == null) return PlanTier.free;
  final plan = summary.plan.toLowerCase();
  final status = summary.status.toLowerCase();
  final now = DateTime.now();
  final isPaidActive = status == 'active' &&
      summary.subscriptionId != null &&
      summary.subscriptionId!.isNotEmpty &&
      (summary.currentPeriodEnd == null || summary.currentPeriodEnd!.isAfter(now));
  if (plan == 'elite' && isPaidActive) return PlanTier.elite;
  if (plan == 'pro' && isPaidActive) return PlanTier.pro;
  return PlanTier.free;
}

PlanQuota? quotaForTier(UserQuotaSummary? quota, PlanTier tier) {
  switch (tier) {
    case PlanTier.pro:
      return quota?.proQuota;
    case PlanTier.trial:
      return quota?.trialQuota;
    case PlanTier.free:
    case PlanTier.elite:
      return null;
  }
}

bool canAccessNutritionist(PlanTier tier) => tier == PlanTier.elite;

bool canAccessRecipes(PlanTier tier) => tier == PlanTier.elite || tier == PlanTier.pro || tier == PlanTier.trial;

bool canAccessAiRegeneration(PlanTier tier) =>
    tier == PlanTier.elite || tier == PlanTier.pro || tier == PlanTier.trial;
