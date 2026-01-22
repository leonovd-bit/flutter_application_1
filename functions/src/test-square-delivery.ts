/**
 * Test Square Delivery Address Resolution
 * Debug why delivery addresses aren't appearing in "Deliver to" field
 */

import {defineSecret} from "firebase-functions/params";
import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

const squareAccessToken = defineSecret("SQUARE_ACCESS_TOKEN");

interface SquareLocation {
  id: string;
  name: string;
  address?: {
    address_line_1?: string;
    locality?: string;
    administrative_district_level_1?: string;
    postal_code?: string;
    country?: string;
  };
}

export const testSquareDeliveryConfig = onRequest(
  {region: "us-central1", secrets: [squareAccessToken]},
  async (request, response): Promise<void> => {
    response.set("Access-Control-Allow-Origin", "*");
    response.set("Access-Control-Allow-Methods", "GET");

    try {
      const accessToken = squareAccessToken.value();
      const locationId = "LGBRPB437S6KJ";
      const baseUrl = "https://connect.squareup.com";

      // Fetch the location to check its capabilities
      const locResponse = await fetch(`${baseUrl}/v2/locations/${locationId}`, {
        method: "GET",
        headers: {
          "Square-Version": "2023-10-18",
          "Authorization": `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
      });

      if (!locResponse.ok) {
        response.status(500).json({
          error: "Failed to fetch location",
          status: locResponse.status,
          statusText: locResponse.statusText,
        });
        return;
      }

      const locData = await locResponse.json();
      const location = locData.location as SquareLocation;

      logger.info("Location details:", {
        id: location.id,
        name: location.name,
        address: location.address,
      });

      // Now fetch a recent delivery order to see its structure
      const now = new Date();
      const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);

      const ordersResponse = await fetch(`${baseUrl}/v2/orders/search`, {
        method: "POST",
        headers: {
          "Square-Version": "2023-10-18",
          "Authorization": `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          location_ids: [locationId],
          query: {
            filter: {
              state_filter: {
                states: ["OPEN", "COMPLETED", "CANCELED"],
              },
              date_time_filter: {
                created_at: {
                  start_at: oneDayAgo.toISOString(),
                  end_at: now.toISOString(),
                },
              },
            },
            sort: {
              sort_field: "CREATED_AT",
              sort_order: "DESC",
            },
          },
          limit: 5,
        }),
      });

      if (!ordersResponse.ok) {
        response.status(500).json({
          error: "Failed to fetch orders",
          status: ordersResponse.status,
          statusText: ordersResponse.statusText,
        });
        return;
      }

      const ordersData = await ordersResponse.json();
      const orders = ordersData.orders || [];

      // Analyze the recent orders for delivery details
      const deliveryOrders = orders.filter((order: any) =>
        order.fulfillments?.some((f: any) => f.type === "DELIVERY")
      );

      const addressSummary = deliveryOrders.map((order: any) => {
        const deliveryFulfillment = order.fulfillments?.find(
          (f: any) => f.type === "DELIVERY"
        );
        const deliveryDetails = deliveryFulfillment?.delivery_details;

        return {
          orderId: order.id,
          reference: order.reference_id,
          state: order.state,
          hasDeliveryDetails: !!deliveryDetails,
          deliveryAddress: deliveryDetails?.delivery_address || null,
          recipientDisplayName: deliveryDetails?.recipient?.display_name,
          fulfillmentState: deliveryFulfillment?.state,
        };
      });

      response.json({
        location: {
          id: location.id,
          name: location.name,
          address: location.address,
        },
        recentDeliveryOrders: {
          total: orders.length,
          withDelivery: deliveryOrders.length,
          samples: addressSummary,
        },
        analysis: {
          addressFieldsInOrders: addressSummary
            .filter((o: any) => o.deliveryAddress)
            .length > 0,
          exampleAddressFormat: addressSummary.find((o: any) => o.deliveryAddress)?.deliveryAddress || null,
        },
      });
    } catch (error: any) {
      logger.error("testSquareDeliveryConfig error:", error);
      response.status(500).json({
        error: "Test failed",
        details: error.message,
      });
    }
  }
);
