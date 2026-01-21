import 'package:cloud_firestore/cloud_firestore.dart';

class RecipeService {
  const RecipeService();

  static const collectionName = 'recipeRequests';

  Future<int> countRecentRequests({required String userId, Duration window = const Duration(days: 7)}) async {
    final since = DateTime.now().subtract(window);
    final snapshot = await FirebaseFirestore.instance
        .collection(collectionName)
        .where('userId', isEqualTo: userId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .get();
    return snapshot.docs.length;
  }

  Future<void> logRecipeRequest({
    required String userId,
    required String dateKey,
  }) async {
    await FirebaseFirestore.instance.collection(collectionName).add({
      'userId': userId,
      'dateKey': dateKey,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
