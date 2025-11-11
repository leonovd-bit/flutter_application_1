import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {getFirestore} from "firebase-admin/firestore";
import {defineSecret} from "firebase-functions/params";

const SQUARE_ENV = defineSecret("SQUARE_ENV");

function getSquareConfig() {
  const rawEnv = SQUARE_ENV.value();
  const env = (rawEnv ? rawEnv.trim() : "sandbox").toLowerCase();
  return {
    env,
    baseUrl: env === "production" ?
      "https://connect.squareup.com" :
      "https://connect.squareupsandbox.com",
  };
}

/**
 * Check what items are in the Square catalog for a restaurant partner
 */
export const checkSquareCatalog = onRequest(
  {
    region: "us-east4",
    secrets: [SQUARE_ENV],
  },
  async (req, res) => {
    try {
      const db = getFirestore();
      const {baseUrl} = getSquareConfig();

      // Get the most recent restaurant partner
      const partnersSnap = await db.collection("restaurant_partners")
        .orderBy("createdAt", "desc")
        .limit(1)
        .get();

      if (partnersSnap.empty) {
        res.status(404).json({success: false, message: "No restaurant partners found"});
        return;
      }

      const partner = partnersSnap.docs[0];
      const partnerData = partner.data();
      const accessToken = partnerData.squareAccessToken;
      const merchantId = partnerData.squareMerchantId;

      logger.info("Checking Square catalog", {
        restaurantId: partner.id,
        merchantId,
      });

      // Fetch catalog items
      const catalogResponse = await fetch(`${baseUrl}/v2/catalog/list?types=ITEM`, {
        headers: {
          "Square-Version": "2023-10-18",
          "Authorization": `Bearer ${accessToken}`,
        },
      });

      if (!catalogResponse.ok) {
        const errorText = await catalogResponse.text();
        res.status(500).json({
          success: false,
          message: `Square API error: ${catalogResponse.status}`,
          details: errorText,
        });
        return;
      }

      const catalogData = await catalogResponse.json();
      const squareItems = catalogData.objects || [];

      // Extract item names and variations
      const itemsList = squareItems.map((item: any) => {
        if (item.type === "ITEM" && item.item_data) {
          return {
            id: item.id,
            name: item.item_data.name,
            description: item.item_data.description?.substring(0, 100),
            category: item.item_data.category_id,
            variationCount: (item.item_data.variations || []).length,
            variations: (item.item_data.variations || []).map((v: any) => ({
              id: v.id,
              name: v.item_variation_data?.name,
              priceMoney: v.item_variation_data?.price_money,
            })),
          };
        }
        return null;
      }).filter(Boolean);

      // Also get a sample of FreshPunk meals for comparison
      const mealsSnap = await db.collection("meals").limit(20).get();
      const freshpunkMeals = mealsSnap.docs.map((doc) => ({
        id: doc.id,
        name: doc.data().name,
        hasSquareId: !!doc.data().squareItemId,
      }));

      logger.info("Square catalog checked", {
        squareItemsCount: itemsList.length,
        freshpunkMealsCount: freshpunkMeals.length,
      });

      res.status(200).json({
        success: true,
        restaurant: {
          id: partner.id,
          name: partnerData.restaurantName,
          merchantId,
        },
        square: {
          itemsCount: itemsList.length,
          items: itemsList,
        },
        freshpunk: {
          mealsCount: freshpunkMeals.length,
          sampleMeals: freshpunkMeals,
        },
        analysis: {
          squareHasItems: itemsList.length > 0,
          freshpunkHasMeals: freshpunkMeals.length > 0,
          needsManualSync: itemsList.length > 0 && freshpunkMeals.some((m: any) => !m.hasSquareId),
        },
      });
    } catch (error: any) {
      logger.error("Failed to check Square catalog", error);
      res.status(500).json({success: false, message: error.message});
    }
  }
);
