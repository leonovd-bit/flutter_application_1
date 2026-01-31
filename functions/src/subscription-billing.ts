import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import {defineSecret} from "firebase-functions/params";
import Stripe from "stripe";
import {FieldValue, getFirestore, Timestamp, Firestore} from "firebase-admin/firestore";
import {getSquareConfig} from "./square-integration";

const STRIPE_SECRET_KEY = defineSecret("STRIPE_SECRET_KEY");
const SQUARE_ENV = defineSecret("SQUARE_ENV");
const SQUARE_APPLICATION_ID = defineSecret("SQUARE_APPLICATION_ID");

const DELIVERY_FEE_PER_MEAL = 9.75;
const FRESHPUNK_PERCENT = 0.10;
const STRIPE_PERCENT = 0.029;
const STRIPE_FIXED = 0.30;

export const billWeeklySubscriptions = onSchedule(
  {
    schedule: "0 6 * * 1",
    timeZone: "America/New_York",
    secrets: [STRIPE_SECRET_KEY, SQUARE_ENV, SQUARE_APPLICATION_ID],
  },
  async () => {
    const db = getFirestore();
    const now = new Date();

    logger.info("[Billing] Starting weekly subscription billing run", {timestamp: now.toISOString()});

    const usersSnapshot = await db.collection("users")
      .where("subscriptionStatus", "==", "active")
      .get();

    logger.info(`[Billing] Found ${usersSnapshot.docs.length} active users`);

    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const userData = userDoc.data();

      try {
        const cancelEffective = userData.cancelEffectiveDate?.toDate?.() ?? null;
        if (cancelEffective && cancelEffective <= now) {
          await userDoc.ref.set({
            subscriptionStatus: "canceled",
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
          logger.info("[Billing] Subscription canceled (effective date reached)", {userId});
          continue;
        }

        const nextBillingDate = userData.nextBillingDate?.toDate?.() ?? null;
        if (nextBillingDate && nextBillingDate > now) {
          logger.info("[Billing] Skipping user (nextBillingDate in future)", {userId, nextBillingDate});
          continue;
        }

        const mealSelectionsDoc = await db.collection("users").doc(userId)
          .collection("meal_selections")
          .doc("current")
          .get();

        if (!mealSelectionsDoc.exists) {
          logger.warn("[Billing] Missing meal selections", {userId});
          continue;
        }

        const mealSelectionsData = mealSelectionsDoc.data() || {};
        const mealSelections = mealSelectionsData.mealSelections as any[] | undefined;
        const restaurantId = mealSelectionsData.restaurantId as string | undefined;

        if (!mealSelections || mealSelections.length === 0 || !restaurantId) {
          logger.warn("[Billing] Missing meal selections or restaurant", {userId});
          continue;
        }

        const scheduleSnapshot = await db.collection("users").doc(userId)
          .collection("delivery_schedules")
          .where("isActive", "==", true)
          .get();

        if (scheduleSnapshot.empty) {
          logger.warn("[Billing] Missing delivery schedules", {userId});
          continue;
        }

        const deliverySchedule: Record<string, Record<string, {time: string; address: string}>> = {};
        scheduleSnapshot.docs.forEach((doc) => {
          const s = doc.data();
          const day = (s.dayOfWeek || "").toString();
          const mealType = (s.mealType || "").toString();
          const time = (s.deliveryTime || "12:00").toString();
          const address = (s.addressId || "default").toString();
          if (!day || !mealType) return;
          const dayKey = day.charAt(0).toUpperCase() + day.slice(1).toLowerCase();
          deliverySchedule[dayKey] = deliverySchedule[dayKey] || {};
          deliverySchedule[dayKey][mealType] = {time, address};
        });

        const mealSubtotal = mealSelections.reduce((sum, meal) => sum + (Number(meal.price) || 0), 0);
        const mealCount = mealSelections.length;
        const deliveryFees = mealCount * DELIVERY_FEE_PER_MEAL;
        const freshpunkFee = mealSubtotal * FRESHPUNK_PERCENT;
        const stripeFee = (freshpunkFee * STRIPE_PERCENT) + STRIPE_FIXED;
        const stripeChargeTotal = freshpunkFee + stripeFee;
        const squareChargeTotal = (mealSubtotal - freshpunkFee) + deliveryFees;

        // Charge Square using stored card
        const squareProfileDoc = await db.collection("users").doc(userId)
          .collection("square_payment_profiles")
          .doc(restaurantId)
          .get();

        if (!squareProfileDoc.exists) {
          logger.warn("[Billing] Missing Square payment profile", {userId, restaurantId});
          continue;
        }

        const squareProfile = squareProfileDoc.data() || {};
        const squareCardId = squareProfile.squareCardId as string | undefined;
        const squareCustomerId = squareProfile.squareCustomerId as string | undefined;
        const squareLocationId = squareProfile.locationId as string | undefined;

        if (!squareCardId || !squareLocationId) {
          logger.warn("[Billing] Missing Square card/location", {userId, restaurantId});
          continue;
        }

        const restaurantDoc = await db.collection("restaurant_partners").doc(restaurantId).get();
        if (!restaurantDoc.exists) {
          logger.warn("[Billing] Restaurant not found", {restaurantId});
          continue;
        }

        const restaurant = restaurantDoc.data()!;
        const accessToken = restaurant.squareAccessToken;
        const locationId = squareLocationId || restaurant.squareLocationId || restaurant.squareMerchantId;
        if (!accessToken || !locationId) {
          logger.warn("[Billing] Restaurant Square credentials incomplete", {restaurantId});
          continue;
        }

        const {baseUrl} = getSquareConfig();

        const squareResp = await fetch(`${baseUrl}/v2/payments`, {
          method: "POST",
          headers: {
            "Square-Version": "2023-10-18",
            "Authorization": `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            idempotency_key: `fp_week_${userId}_${Date.now()}`.slice(0, 45),
            amount_money: {amount: Math.round(squareChargeTotal * 100), currency: "USD"},
            source_id: squareCardId,
            location_id: locationId,
            customer_id: squareCustomerId,
            note: "FreshPunk weekly meals + delivery",
          }),
        });

        const squareData = await squareResp.json();
        if (!squareResp.ok) {
          logger.error("[Billing] Square payment failed", {
            userId,
            restaurantId,
            status: squareResp.status,
            errors: squareData.errors,
          });
          continue;
        }

        // Charge Stripe (platform fee)
        const stripeKey = STRIPE_SECRET_KEY.value();
        if (!stripeKey) {
          logger.error("[Billing] STRIPE_SECRET_KEY not configured");
          continue;
        }

        const stripe = new Stripe(stripeKey, {apiVersion: "2025-06-30.basil" as any});
        const stripeCustomerId = userData.stripeCustomerId as string | undefined;
        if (!stripeCustomerId) {
          logger.warn("[Billing] Missing stripeCustomerId", {userId});
          continue;
        }

        const invoice = await stripe.invoices.create({
          customer: stripeCustomerId,
          collection_method: "charge_automatically",
          auto_advance: false,
          metadata: {
            userId,
            subscriptionType: "meal_subscription",
            billingCycle: new Date().toISOString().split("T")[0],
          },
        });

        if (!invoice.id) {
          throw new Error("Stripe invoice creation failed: missing invoice id");
        }

        await stripe.invoiceItems.create({
          customer: stripeCustomerId,
          invoice: invoice.id,
          amount: Math.round(freshpunkFee * 100),
          currency: "usd",
          description: "FreshPunk Service Fee (10% of meals)",
          metadata: {type: "freshpunk_fee", percent: 10},
        });

        if (stripeFee > 0) {
          await stripe.invoiceItems.create({
            customer: stripeCustomerId,
            invoice: invoice.id,
            amount: Math.round(stripeFee * 100),
            currency: "usd",
            description: "Payment Processing Fee",
            metadata: {type: "stripe_fee", percent: 2.9, fixed: 0.30},
          });
        }

        const finalizedInvoice = await stripe.invoices.finalizeInvoice(invoice.id);

        if (!finalizedInvoice.id) {
          throw new Error("Stripe invoice finalize failed: missing invoice id");
        }

        await db.collection("users").doc(userId)
          .collection("invoices")
          .doc(finalizedInvoice.id)
          .set({
            stripeInvoiceId: finalizedInvoice.id,
            customerId: stripeCustomerId,
            status: "finalized",
            amountCents: Math.round(stripeChargeTotal * 100),
            amountDollars: stripeChargeTotal,
            breakdown: {
              mealSubtotal,
              deliveryFees,
              freshpunkFee,
              stripeFee,
              stripeChargeTotal,
              squareChargeTotal,
            },
            mealCount,
            billingCycle: new Date().toISOString().split("T")[0],
            createdAt: FieldValue.serverTimestamp(),
            mealSelections: mealSelections.slice(0, 100),
          });

        // Generate orders for the next week
        await generateOrdersForUser(db, userId, userData, mealSelections, deliverySchedule);

        const nextDate = new Date();
        nextDate.setDate(nextDate.getDate() + 7);
        await userDoc.ref.set({
          lastBilledAt: FieldValue.serverTimestamp(),
          nextBillingDate: Timestamp.fromDate(nextDate),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});

        logger.info("[Billing] User billed successfully", {userId});
      } catch (e: any) {
        logger.error("[Billing] Error billing user", {userId, error: e?.message});
      }
    }
  }
);

async function generateOrdersForUser(
  db: Firestore,
  userId: string,
  userData: any,
  mealSelections: any[],
  deliverySchedule: Record<string, Record<string, {time: string; address: string}>>
) {
  const batch = db.batch();
  const generatedOrders: any[] = [];

  const now = new Date();
  const currentDayOfWeek = now.getDay();
  const daysUntilMonday = currentDayOfWeek === 0 ? 1 : (8 - currentDayOfWeek);
  const nextMonday = new Date(now);
  nextMonday.setDate(now.getDate() + daysUntilMonday);
  nextMonday.setHours(0, 0, 0, 0);

  const daysOfWeek = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
  const mealTypes = ["breakfast", "lunch", "dinner"];

  for (let dayOffset = 0; dayOffset < 7; dayOffset++) {
    const deliveryDate = new Date(nextMonday);
    deliveryDate.setDate(nextMonday.getDate() + dayOffset);
    deliveryDate.setHours(0, 0, 0, 0);

    const dayName = daysOfWeek[deliveryDate.getDay()];
    const daySchedule = deliverySchedule[dayName];
    if (!daySchedule) continue;

    for (const mealType of mealTypes) {
      const mealConfig = daySchedule[mealType];
      if (!mealConfig || !mealConfig.time) continue;

      const [hours, minutes] = mealConfig.time.split(":").map(Number);
      if (Number.isNaN(hours) || Number.isNaN(minutes)) continue;

      const deliveryDateTime = new Date(deliveryDate);
      deliveryDateTime.setUTCHours(hours + 5, minutes, 0, 0); // default to EST offset

      const mealIndex = (dayOffset * 3 + mealTypes.indexOf(mealType)) % mealSelections.length;
      const selectedMeal = mealSelections[mealIndex];
      if (!selectedMeal || !selectedMeal.id) continue;

      const orderPrice = Number(selectedMeal.price) || 0;
      const orderId = `${userId}_${Date.now()}_${dayOffset}_${mealType}`;

      const dispatchReadyDate = new Date(deliveryDateTime);
      dispatchReadyDate.setMinutes(dispatchReadyDate.getMinutes() - 60);

      const orderData = {
        id: orderId,
        userId,
        userEmail: userData.email || "",
        meals: [{
          id: selectedMeal.id,
          name: selectedMeal.name,
          description: selectedMeal.description,
          calories: selectedMeal.calories,
          protein: selectedMeal.protein,
          imageUrl: selectedMeal.imageUrl,
          price: orderPrice,
          mealType,
          restaurantId: selectedMeal.restaurantId || null,
          squareItemId: selectedMeal.squareItemId || null,
          squareVariationId: selectedMeal.squareVariationId || null,
        }],
        deliveryAddress: mealConfig.address || "default",
        orderDate: FieldValue.serverTimestamp(),
        deliveryDate: Timestamp.fromDate(deliveryDateTime),
        estimatedDeliveryTime: Timestamp.fromDate(deliveryDateTime),
        status: "pending",
        totalAmount: orderPrice,
        mealPlanType: userData.currentMealPlan || "nutritious",
        dayName,
        mealType,
        source: "subscription_billing",
        userConfirmed: false,
        userConfirmedAt: null,
        dispatchReadyAt: Timestamp.fromDate(dispatchReadyDate),
        dispatchWindowMinutes: 60,
        dispatchTriggeredAt: null,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      };

      const orderRef = db.collection("orders").doc(orderId);
      batch.set(orderRef, orderData);
      generatedOrders.push(orderData);
    }
  }

  if (generatedOrders.length > 0) {
    await batch.commit();
  }

  logger.info(`[Billing] Generated ${generatedOrders.length} orders`, {userId});
}
