import {onRequest} from "firebase-functions/v2/https";
import {getFirestore} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

/**
 * Diagnostic endpoint to inspect meal data structure
 * GET https://<region>-<project>.cloudfunctions.net/diagnosticMeals
 */
export const diagnosticMeals = onRequest(async (req, res) => {
  const db = getFirestore();

  try {
    // Query all restaurant partners
    const partnersSnap = await db.collection("restaurant_partners").get();
    const result: any = {
      timestamp: new Date().toISOString(),
      restaurantPartners: [],
      flatMeals: [],
      nestedMeals: {},
    };

    // Check each restaurant partner for nested meals
    for (const partnerDoc of partnersSnap.docs) {
      const partnerData = partnerDoc.data();
      result.restaurantPartners.push({
        id: partnerDoc.id,
        name: partnerData.restaurantName || partnerDoc.id,
        hasMeals: false,
        mealCount: 0,
      });

      // Query nested meals: meals/{partnerId}/items
      try {
        const itemsSnap = await db
          .collection("meals")
          .doc(partnerDoc.id)
          .collection("items")
          .limit(100)
          .get();

        if (!itemsSnap.empty) {
          const partner = result.restaurantPartners[result.restaurantPartners.length - 1];
          partner.hasMeals = true;
          partner.mealCount = itemsSnap.size;

          const meals = itemsSnap.docs.map((doc) => {
            const data = doc.data();
            return {
              id: doc.id,
              name: data.name || "Unknown",
              hasSquareItemId: !!data.squareItemId,
              hasSquareVariationId: !!data.squareVariationId,
              hasRestaurantId: !!data.restaurantId,
              squareItemId: data.squareItemId || null,
              squareVariationId: data.squareVariationId || null,
              restaurantId: data.restaurantId || null,
            };
          });

          result.nestedMeals[partnerDoc.id] = meals;
        }
      } catch (err) {
        logger.warn(`Could not query meals/${partnerDoc.id}/items`, {error: (err as any).message});
      }
    }

    // Check flat meals collection (legacy)
    try {
      const flatMealsSnap = await db.collection("meals").limit(20).get();
      result.flatMeals = flatMealsSnap.docs
        .filter((doc) => {
          // Skip restaurant parent docs (they're not meals)
          const data = doc.data();
          return data.name || data.description || data.calories;
        })
        .map((doc) => {
          const data = doc.data();
          return {
            id: doc.id,
            name: data.name || "Unknown",
            hasSquareItemId: !!data.squareItemId,
            hasSquareVariationId: !!data.squareVariationId,
            hasRestaurantId: !!data.restaurantId,
          };
        });
    } catch (err) {
      logger.warn("Could not query flat meals collection", {error: (err as any).message});
    }

    // Return formatted JSON
    res.set("Content-Type", "application/json");
    res.status(200).send(JSON.stringify(result, null, 2));
  } catch (err) {
    logger.error("diagnosticMeals failed", {error: (err as any).message});
    res.status(500).send({
      error: "Internal server error",
      message: (err as any).message,
    });
  }
});
