// E:\chatapplication\functions\index.js

// Import necessary modules
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");

const {setGlobalOptions} = require("firebase-functions");

// 1. Initialize Firebase Admin SDK
admin.initializeApp();

// For cost control, you can set the maximum number of containers that can be
// running at the same time. (Keeping existing v2 setup)
setGlobalOptions({maxInstances: 10});


// 2. SELF-DESTRUCTING MESSAGES: Scheduled Cloud Function (v1 API)
// This function runs every 15 minutes to delete messages where 
// destructionTime is in the past.
exports.deleteExpiredMessages = functions.pubsub
    .schedule("every 15 minutes")
    // Set maxInstances here for v1 API compatibility and cost control
    .runWith({maxInstances: 1})
    .onRun(async (context) => {
      const now = admin.firestore.Timestamp.now();

      // Query messages across ALL chat rooms where destructionTime has passed
      const expiredMessages = await admin.firestore()
          .collectionGroup("messages")
          .where("destructionTime", "<=", now)
          .get();

      if (expiredMessages.empty) {
        logger.log("No expired messages found.");
        return null;
      }

      // Use a batch write to efficiently delete multiple documents
      const batch = admin.firestore().batch();
      let deletedCount = 0;

      expiredMessages.docs.forEach((doc) => {
        batch.delete(doc.ref);
        deletedCount++;
      });

      await batch.commit();
      logger.log(`Successfully deleted ${deletedCount} expired messages.`);

      return null;
    });

// The commented-out template code has been fully removed for cleanliness.
