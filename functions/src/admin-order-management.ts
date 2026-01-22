/**
 * Admin functions for order management
 * - Edit orders before confirmation
 * - Manually trigger Square forwarding
 */

import {onRequest} from "firebase-functions/v2/https";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

/**
 * Edit order details (before confirmation)
 * POST /editOrder
 * Body: { orderId, customerName?, customerPhone?, customerEmail?, deliveryAddress?, specialInstructions?, items? }
 */
export const editOrder = onRequest(
  {region: "us-central1"},
  async (request, response): Promise<void> => {
    response.set("Access-Control-Allow-Origin", "*");
    response.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    response.set("Access-Control-Allow-Headers", "Content-Type");

    if (request.method === "OPTIONS") {
      response.status(204).send("");
      return;
    }

    if (request.method !== "POST") {
      response.status(400).json({error: "Use POST method"});
      return;
    }

    try {
      const db = getFirestore();
      const {orderId, ...updates} = request.body;

      if (!orderId) {
        response.status(400).json({error: "orderId required"});
        return;
      }

      // Get current order
      const orderRef = db.collection("orders").doc(orderId);
      const orderSnap = await orderRef.get();

      if (!orderSnap.exists) {
        response.status(404).json({error: "Order not found"});
        return;
      }

      const currentData = orderSnap.data();

      // Only allow editing if order is not already confirmed/sent to Square
      if (currentData?.status === "confirmed" || currentData?.squareOrders) {
        response.status(400).json({
          error: "Cannot edit order after it has been confirmed/sent to Square",
          currentStatus: currentData?.status,
        });
        return;
      }

      // Build update object with allowed fields
      const updateData: any = {
        updatedAt: FieldValue.serverTimestamp(),
      };

      if (updates.customerName !== undefined) updateData.customerName = updates.customerName;
      if (updates.customerPhone !== undefined) updateData.customerPhone = updates.customerPhone;
      if (updates.customerEmail !== undefined) updateData.customerEmail = updates.customerEmail;
      if (updates.specialInstructions !== undefined) updateData.specialInstructions = updates.specialInstructions;

      // Handle nested address object
      if (updates.deliveryAddress) {
        updateData.deliveryAddress = {
          streetAddress: updates.deliveryAddress.streetAddress || currentData?.deliveryAddress?.streetAddress,
          city: updates.deliveryAddress.city || currentData?.deliveryAddress?.city,
          state: updates.deliveryAddress.state || currentData?.deliveryAddress?.state,
          zipCode: updates.deliveryAddress.zipCode || currentData?.deliveryAddress?.zipCode,
        };
      }

      // Handle items/meals
      if (updates.items !== undefined && Array.isArray(updates.items)) {
        updateData.items = updates.items;
        // Also update meals if provided
        if (updates.meals !== undefined && Array.isArray(updates.meals)) {
          updateData.meals = updates.meals;
        }
      }

      // Apply update
      await orderRef.update(updateData);

      logger.info("Order edited", {
        orderId,
        editedFields: Object.keys(updates),
      });

      response.json({
        success: true,
        orderId,
        message: "Order updated successfully",
        updatedFields: Object.keys(updateData).filter((k) => k !== "updatedAt"),
      });
    } catch (error: any) {
      logger.error("editOrder error:", error);
      response.status(500).json({
        error: "Failed to edit order",
        details: error.message,
      });
    }
  }
);

/**
 * Manually forward existing order to Square
 * POST /manuallyForwardOrder
 * Body: { orderId }
 */
export const manuallyForwardOrder = onRequest(
  {region: "us-central1"},
  async (request, response): Promise<void> => {
    response.set("Access-Control-Allow-Origin", "*");
    response.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    response.set("Access-Control-Allow-Headers", "Content-Type");

    if (request.method === "OPTIONS") {
      response.status(204).send("");
      return;
    }

    if (request.method !== "POST") {
      response.status(400).json({error: "Use POST method"});
      return;
    }

    try {
      const db = getFirestore();
      const {orderId} = request.body;

      if (!orderId) {
        response.status(400).json({error: "orderId required"});
        return;
      }

      // Get order
      const orderRef = db.collection("orders").doc(orderId);
      const orderSnap = await orderRef.get();

      if (!orderSnap.exists) {
        response.status(404).json({error: "Order not found"});
        return;
      }

      const orderData = orderSnap.data();

      // Check if order has been sent to Square already
      if (orderData?.squareOrders && Object.keys(orderData.squareOrders).length > 0) {
        response.status(400).json({
          error: "Order already forwarded to Square",
          squareOrderIds: Object.values(orderData.squareOrders).map((o: any) => o.squareOrderId),
        });
        return;
      }

      // Trigger forwarding by changing status to confirmed
      // This will trigger the onDocumentUpdated listener
      await orderRef.update({
        status: "confirmed",
        forwardedManually: true,
        forwardedManuallyAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      logger.info("Order manually forwarded", {orderId});

      response.json({
        success: true,
        orderId,
        message: "Order marked for forwarding to Square (will process within seconds)",
        note: "Check Firebase logs or Square dashboard in a few seconds to confirm",
      });
    } catch (error: any) {
      logger.error("manuallyForwardOrder error:", error);
      response.status(500).json({
        error: "Failed to forward order",
        details: error.message,
      });
    }
  }
);
