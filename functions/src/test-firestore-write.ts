/**
 * Test write to Firestore - diagnose if writes are working
 */

import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {getFirestore} from "firebase-admin/firestore";

export const testFirestoreWrite = onRequest(
  {region: "us-central1", timeoutSeconds: 30},
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");

    try {
      const db = getFirestore();
      const testId = `test_${Date.now()}`;

      // Try writing to a test collection
      const writeStart = Date.now();
      await db.collection("_test_writes").doc(testId).set({
        timestamp: new Date(),
        message: "Test write successful",
      });
      const writeMs = Date.now() - writeStart;

      // Try reading it back
      const readStart = Date.now();
      const doc = await db.collection("_test_writes").doc(testId).get();
      const readMs = Date.now() - readStart;

      res.json({
        success: true,
        testId,
        write_ms: writeMs,
        read_ms: readMs,
        document_exists: doc.exists,
        timestamp: new Date().toISOString(),
      });
    } catch (error: any) {
      logger.error("Firestore test error", {error: error.message, stack: error.stack});
      res.status(500).json({
        success: false,
        error: error.message,
        timestamp: new Date().toISOString(),
      });
    }
  }
);
