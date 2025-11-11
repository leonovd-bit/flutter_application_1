import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import fetch from "node-fetch";

export const proxyImage = functions.https.onRequest(async (req, res) => {
    // Set CORS headers
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "GET, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    // Handle preflight requests
    if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
    }

    const imagePath = req.query.path as string;
    if (!imagePath) {
        res.status(400).send("Image path is required");
        return;
    }

    try {
        // Get the download URL for the image
        const bucket = admin.storage().bucket();
        const file = bucket.file(decodeURIComponent(imagePath));
        const [signedUrl] = await file.getSignedUrl({
            action: "read",
            expires: Date.now() + 5 * 60 * 1000, // URL expires in 5 minutes
        });

        // Fetch the image
        const response = await fetch(signedUrl);
        const buffer = await response.buffer();

        // Set content type and serve the image
        res.set("Content-Type", response.headers.get("content-type") || "image/jpeg");
        res.send(buffer);
    } catch (error) {
        console.error("Error proxying image:", error);
        res.status(500).send("Error fetching image");
    }
});
