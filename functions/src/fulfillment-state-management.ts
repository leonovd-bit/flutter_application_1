import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {CallableRequest, CallableResponse} from "firebase-functions/v2/https";

const db = admin.firestore();

// Valid fulfillment state transitions in Square
// PROPOSED -> ACCEPTED -> PREPARED -> COMPLETED
// or PROPOSED -> REJECTED -> CANCELED

type FulfillmentState = "PROPOSED" | "ACCEPTED" | "PREPARED" | "COMPLETED" | "REJECTED" | "CANCELED";

interface UpdateFulfillmentStateRequest {
  orderId: string;
  squareOrderId: string;
  restaurantId?: string;
  newState: FulfillmentState;
}

/**
 * Update fulfillment state in Square for an order
 * Handles the state progression: PROPOSED -> ACCEPTED -> PREPARED -> COMPLETED
 * Called when kitchen accepts order, starts prep, or completes order
 */
export const updateFulfillmentState = functions.https.onCall<UpdateFulfillmentStateRequest>(
  async (request: CallableRequest<UpdateFulfillmentStateRequest>, response?: CallableResponse<unknown>) => {
    const data = request.data;
    const {orderId, squareOrderId, newState} = data;

    if (!orderId || !squareOrderId || !newState) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing required fields: orderId, squareOrderId, newState"
      );
    }

    // Validate state is one of the allowed values
    const validStates: FulfillmentState[] = ["PROPOSED", "ACCEPTED", "PREPARED", "COMPLETED"];
    if (!validStates.includes(newState)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        `Invalid state: ${newState}. Must be one of: ${validStates.join(", ")}`
      );
    }

    const accessToken = process.env.SQUARE_ACCESS_TOKEN;
    if (!accessToken) {
      throw new functions.https.HttpsError(
        "internal",
        "SQUARE_ACCESS_TOKEN not configured"
      );
    }

    const squareEnv = process.env.SQUARE_ENV || "sandbox";
    const baseUrl = squareEnv === "production" ?
      "https://connect.squareup.com" :
      "https://connect.squareupsandbox.com";

    try {
      // Fetch current order from Square to get version and fulfillment UIDs
      const getResp = await fetch(`${baseUrl}/v2/orders/${squareOrderId}`, {
        method: "GET",
        headers: {
          "Square-Version": "2023-10-18",
          "Authorization": `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
      });

      if (!getResp.ok) {
        const errText = await getResp.text().catch(() => "<no-body>");
        functions.logger.error("Failed to fetch order from Square", {
          orderId,
          squareOrderId,
          status: getResp.status,
          error: errText,
        });
        throw new functions.https.HttpsError(
          "internal",
          `Failed to fetch order: ${getResp.status}`
        );
      }

      const orderData = await getResp.json();
      const currentVersion = orderData.order?.version;
      const fulfillments = orderData.order?.fulfillments || [];

      if (!fulfillments.length) {
        throw new functions.https.HttpsError(
          "not-found",
          "Order has no fulfillments"
        );
      }

      // Update each fulfillment to the new state
      let updateSuccessful = false;
      let lastError = "";

      for (const fulfillment of fulfillments) {
        try {
          const updateResp = await fetch(`${baseUrl}/v2/orders/${squareOrderId}`, {
            method: "PUT",
            headers: {
              "Square-Version": "2023-10-18",
              "Authorization": `Bearer ${accessToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              order: {
                version: currentVersion,
                fulfillments: [{
                  uid: fulfillment.uid,
                  state: newState,
                }],
              },
              idempotency_key: `${orderId}_${newState}_${Date.now()}`,
            }),
          });

          if (updateResp.ok) {
            const responseData = await updateResp.json();
            updateSuccessful = true;
            functions.logger.info("Fulfillment state updated in Square", {
              orderId,
              squareOrderId,
              newState,
              fulfillmentUid: fulfillment.uid,
              orderVersion: responseData.order?.version,
            });

            // Update Firestore order document with new state
            await db.collection("orders").doc(orderId).update({
              squareFulfillmentState: newState,
              lastStateUpdate: admin.firestore.FieldValue.serverTimestamp(),
              lastStateUpdateTimestamp: new Date().toISOString(),
            });

            // Log state update to order history
            await db.collection("orders").doc(orderId).collection("stateHistory").add({
              previousState: fulfillment.state,
              newState,
              timestamp: admin.firestore.FieldValue.serverTimestamp(),
              source: "updateFulfillmentState",
            });
          } else {
            const errText = await updateResp.text().catch(() => "<no-body>");
            lastError = `Update failed: ${(errText as string)?.slice(0, 300)}`;
            functions.logger.warn("Fulfillment state update failed", {
              orderId,
              squareOrderId,
              newState,
              status: updateResp.status,
              error: (errText as string)?.slice(0, 500),
            });
          }
        } catch (error) {
          lastError = `Exception: ${String(error)}`;
          functions.logger.error("Error updating fulfillment state", {
            orderId,
            squareOrderId,
            error: String(error),
          });
        }
      }

      if (!updateSuccessful) {
        throw new functions.https.HttpsError(
          "internal",
          `Failed to update fulfillment state: ${lastError}`
        );
      }

      return {
        success: true,
        orderId,
        squareOrderId,
        newState,
        message: `Order state updated to ${newState}`,
      };
    } catch (error) {
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      functions.logger.error("Unexpected error updating fulfillment state", {
        orderId,
        squareOrderId,
        error: String(error),
      });
      throw new functions.https.HttpsError(
        "internal",
        `Error updating fulfillment state: ${String(error)}`
      );
    }
  }
);

/**
 * HTTP endpoint to update fulfillment state
 * POST /updateFulfillmentStateHttp
 * Body: {orderId, squareOrderId, restaurantId, newState}
 */
export const updateFulfillmentStateHttp = functions.https.onRequest(
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method not allowed");
      return;
    }

    const {orderId, squareOrderId, newState} = req.body;

    if (!orderId || !squareOrderId || !newState) {
      res.status(400).json({
        error: "Missing required fields: orderId, squareOrderId, newState",
      });
      return;
    }

    const validStates = ["PROPOSED", "ACCEPTED", "PREPARED", "COMPLETED"];
    if (!validStates.includes(newState)) {
      res.status(400).json({
        error: `Invalid state: ${newState}. Must be one of: ${validStates.join(", ")}`,
      });
      return;
    }

    const accessToken = process.env.SQUARE_ACCESS_TOKEN;
    if (!accessToken) {
      res.status(500).json({error: "SQUARE_ACCESS_TOKEN not configured"});
      return;
    }

    const squareEnv = process.env.SQUARE_ENV || "sandbox";
    const baseUrl = squareEnv === "production" ?
      "https://connect.squareup.com" :
      "https://connect.squareupsandbox.com";

    try {
      // Fetch current order from Square
      const getResp = await fetch(`${baseUrl}/v2/orders/${squareOrderId}`, {
        method: "GET",
        headers: {
          "Square-Version": "2023-10-18",
          "Authorization": `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
      });

      if (!getResp.ok) {
        await getResp.text().catch(() => "<no-body>");
        functions.logger.error("Failed to fetch order from Square", {
          orderId,
          squareOrderId,
          status: getResp.status,
        });
        res.status(getResp.status).json({
          error: "Failed to fetch order from Square",
        });
        return;
      }

      const orderData = await getResp.json();
      const currentVersion = orderData.order?.version;
      const fulfillments = orderData.order?.fulfillments || [];

      if (!fulfillments.length) {
        res.status(404).json({error: "Order has no fulfillments"});
        return;
      }

      // Update fulfillment state
      let updateSuccessful = false;
      let lastError = "";

      for (const fulfillment of fulfillments) {
        try {
          const updateResp = await fetch(`${baseUrl}/v2/orders/${squareOrderId}`, {
            method: "PUT",
            headers: {
              "Square-Version": "2023-10-18",
              "Authorization": `Bearer ${accessToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              order: {
                version: currentVersion,
                fulfillments: [{
                  uid: fulfillment.uid,
                  state: newState,
                }],
              },
              idempotency_key: `${orderId}_${newState}_${Date.now()}`,
            }),
          });

          if (updateResp.ok) {
            await updateResp.json();
            updateSuccessful = true;
            functions.logger.info("Fulfillment state updated in Square (HTTP)", {
              orderId,
              squareOrderId,
              newState,
            });

            // Update Firestore
            await db.collection("orders").doc(orderId).update({
              squareFulfillmentState: newState,
              lastStateUpdate: admin.firestore.FieldValue.serverTimestamp(),
            });
          } else {
            const errText = await updateResp.text().catch(() => "<no-body>");
            lastError = errText?.slice(0, 300) || "Unknown error";
          }
        } catch (error) {
          lastError = String(error);
        }
      }

      if (!updateSuccessful) {
        res.status(500).json({
          error: `Failed to update fulfillment state: ${lastError}`,
        });
        return;
      }

      res.json({
        success: true,
        orderId,
        squareOrderId,
        newState,
        message: `Order state updated to ${newState}`,
      });
    } catch (error) {
      functions.logger.error("Error in updateFulfillmentStateHttp", {error: String(error)});
      res.status(500).json({
        error: `Internal server error: ${String(error)}`,
      });
    }
  }
);

/**
 * Firestore-triggered function that monitors order status changes
 * When FreshPunk order status changes, update the corresponding Square fulfillment state
 * Status mapping:
 * - "pending" -> PROPOSED (not yet accepted by kitchen)
 * - "confirmed" -> PROPOSED (sent to restaurant)
 * - "preparing" -> ACCEPTED (kitchen started)
 * - "ready" -> PREPARED (kitchen finished, ready for delivery)
 * - "completed" -> COMPLETED (order fulfilled)
 * - "cancelled" -> CANCELED
 */
export const syncOrderStatusToSquare = functions
  .firestore
  .onDocumentUpdated("orders/{orderId}",
    async (event: any) => {
      const orderId = event.params.orderId;
      const prevData = event.data.before.data();
      const newData = event.data.after.data();

      const prevStatus = prevData?.status;
      const newStatus = newData?.status;

      // Only process if status changed
      if (prevStatus === newStatus) {
        return;
      }

      const squareOrderId = newData?.squareOrderId;

    if (!squareOrderId) {
      functions.logger.info("Order has no Square order ID, skipping sync", {orderId});
      return;
    }

    // Map FreshPunk status to Square fulfillment state
    let squareState: FulfillmentState | null = null;

    switch (newStatus) {
      case "pending":
      case "confirmed":
        squareState = "PROPOSED";
        break;
      case "preparing":
        squareState = "ACCEPTED";
        break;
      case "ready":
        squareState = "PREPARED";
        break;
      case "completed":
        squareState = "COMPLETED";
        break;
      case "cancelled":
        squareState = "CANCELED";
        break;
      default:
        functions.logger.warn("Unknown order status", {orderId, newStatus});
        return;
    }

    try {
      const accessToken = process.env.SQUARE_ACCESS_TOKEN;
      if (!accessToken) {
        functions.logger.error("SQUARE_ACCESS_TOKEN not configured");
        return;
      }

      const squareEnv = process.env.SQUARE_ENV || "sandbox";
      const baseUrl = squareEnv === "production" ?
        "https://connect.squareup.com" :
        "https://connect.squareupsandbox.com";

      // Fetch order to get version
      const getResp = await fetch(`${baseUrl}/v2/orders/${squareOrderId}`, {
        method: "GET",
        headers: {
          "Square-Version": "2023-10-18",
          "Authorization": `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
      });

      if (!getResp.ok) {
        functions.logger.warn("Failed to fetch order from Square for sync", {
          orderId,
          squareOrderId,
          status: getResp.status,
        });
        return;
      }

      const orderData = await getResp.json();
      const currentVersion = orderData.order?.version;
      const fulfillments = orderData.order?.fulfillments || [];

      if (!fulfillments.length) {
        functions.logger.info("Order has no fulfillments, skipping sync", {orderId});
        return;
      }

      // Update fulfillment state
      for (const fulfillment of fulfillments) {
        try {
          const updateResp = await fetch(`${baseUrl}/v2/orders/${squareOrderId}`, {
            method: "PUT",
            headers: {
              "Square-Version": "2023-10-18",
              "Authorization": `Bearer ${accessToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              order: {
                version: currentVersion,
                fulfillments: [{
                  uid: fulfillment.uid,
                  state: squareState,
                }],
              },
              idempotency_key: `${orderId}_sync_${newStatus}_${Date.now()}`,
            }),
          });

          if (updateResp.ok) {
            functions.logger.info("Order status synced to Square", {
              orderId,
              squareOrderId,
              freshpunkStatus: newStatus,
              squareState,
            });
          } else {
            functions.logger.warn("Failed to sync order status to Square", {
              orderId,
              squareOrderId,
              status: updateResp.status,
            });
          }
        } catch (error) {
          functions.logger.error("Error syncing order status to Square", {
            orderId,
            error: String(error),
          });
        }
      }
    } catch (error) {
      functions.logger.error("Unexpected error in syncOrderStatusToSquare", {
        orderId,
        error: String(error),
      });
    }
  });
