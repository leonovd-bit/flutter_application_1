/**
 * Verify that addresses are actually stored in Square
 * Fetches recent orders and displays delivery address details
 */

import {defineSecret} from "firebase-functions/params";
import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

const squareAccessToken = defineSecret("SQUARE_ACCESS_TOKEN");

export const verifySquareAddresses = onRequest(
  {region: "us-central1", secrets: [squareAccessToken]},
  async (request, response): Promise<void> => {
    response.set("Access-Control-Allow-Origin", "*");
    response.set("Access-Control-Allow-Methods", "GET, POST");

    try {
      const accessToken = squareAccessToken.value();
      const locationId = "LGBRPB437S6KJ";
      const baseUrl = "https://connect.squareup.com";

      // Search for recent orders (last 24 hours)
      const now = new Date();
      const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000);

      const searchResp = await fetch(`${baseUrl}/v2/orders/search`, {
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
              date_time_filter: {
                created_at: {
                  start_at: yesterday.toISOString(),
                },
              },
            },
            sort: {
              sort_field: "CREATED_AT",
              sort_order: "DESC",
            },
          },
          limit: 10,
        }),
      });

      if (!searchResp.ok) {
        response.status(searchResp.status).json({
          error: "Failed to search orders",
          status: searchResp.status,
          statusText: searchResp.statusText,
        });
        return;
      }

      const searchData = await searchResp.json();
      const orders = searchData.orders || [];

      logger.info("Found orders", {count: orders.length});

      // Analyze delivery orders
      const analysis = orders.map((order: any) => {
        const deliveryFulfillment = order.fulfillments?.find(
          (f: any) => f.type === "DELIVERY"
        );

        if (!deliveryFulfillment) {
          return {
            orderId: order.id,
            hasDelivery: false,
          };
        }

        const deliveryDetails = deliveryFulfillment.delivery_details || {};
        const addr = deliveryDetails.delivery_address || {};
        const recipient = deliveryDetails.recipient || {};

        return {
          orderId: order.id.substring(0, 12),
          reference: order.reference_id,
          state: order.state,
          hasDelivery: true,
          recipient: {
            displayName: recipient.display_name,
            phone: recipient.phone_number,
            email: recipient.email_address,
          },
          deliveryAddress: {
            address_line_1: addr.address_line_1 || null,
            address_line_2: addr.address_line_2 || null,
            locality: addr.locality || null,
            administrativeDistrict: addr.administrative_district_level_1 || null,
            postalCode: addr.postal_code || null,
            country: addr.country || null,
          },
          metadata: {
            freshpunk_order_id: order.metadata?.freshpunk_order_id,
            delivery_address_meta: order.metadata?.delivery_address,
          },
        };
      });

      const deliveryOrders = analysis.filter((o: any) => o.hasDelivery);
      const ordersWithAddresses = deliveryOrders.filter((o: any) =>
        o.deliveryAddress.address_line_1 || o.deliveryAddress.locality
      );

      response.json({
        summary: {
          totalOrders: orders.length,
          deliveryOrders: deliveryOrders.length,
          ordersWithStoredAddresses: ordersWithAddresses.length,
          percentage: ordersWithAddresses.length > 0 ?
            Math.round((ordersWithAddresses.length / deliveryOrders.length) * 100) :
            0,
        },
        verification: {
          addressesAreStored: ordersWithAddresses.length > 0,
          addressFormat: ordersWithAddresses.length > 0 ?
            ordersWithAddresses[0].deliveryAddress :
            null,
        },
        recentDeliveryOrders: analysis
          .filter((o: any) => o.hasDelivery)
          .slice(0, 5),
        allOrders: analysis.slice(0, 10),
      });
    } catch (error: any) {
      logger.error("verifySquareAddresses error:", error);
      response.status(500).json({
        error: "Verification failed",
        details: error.message,
      });
    }
  }
);
