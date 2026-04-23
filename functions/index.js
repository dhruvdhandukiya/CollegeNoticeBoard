const functions = require("firebase-functions");
const admin     = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();

exports.onNoticeCreated = functions.firestore
  .document("notices/{noticeId}")
  .onCreate(async (snap, context) => {
    const notice   = snap.data();
    const noticeId = context.params.noticeId;

    console.log("New notice created:", notice.title, "visibility:", notice.visibility);

    // Build the notification payload
    const notificationTitle = notice.isImportant
      ? `🔴 IMPORTANT: ${notice.title}`
      : notice.priority === "urgent"
        ? `🚨 URGENT: ${notice.title}`
        : `📢 ${notice.title}`;

    const notificationBody = notice.description.length > 100
      ? notice.description.substring(0, 100) + "..."
      : notice.description;

    // Find eligible students based on visibility
    let query = db.collection("users")
      .where("isActive", "==", true)
      .where("role", "!=", "admin");

    let studentDocs;

    switch (notice.visibility) {
      case "all":
        studentDocs = await query.get();
        break;

      case "department":
        studentDocs = await query
          .where("department", "==", notice.targetDepartment)
          .get();
        break;

      case "year":
        studentDocs = await query
          .where("year", "==", notice.targetYear)
          .get();
        break;

      case "committee":
        studentDocs = await query
          .where("committee", "==", notice.targetCommittee)
          .get();
        break;

      case "specific":
        // targetStudentUids is an array — fetch in batches of 10 (Firestore limit)
        const uids     = notice.targetStudentUids || [];
        const allDocs  = [];
        const batchSize = 10;
        for (let i = 0; i < uids.length; i += batchSize) {
          const batch = uids.slice(i, i + batchSize);
          const batchSnap = await db.collection("users")
            .where(admin.firestore.FieldPath.documentId(), "in", batch)
            .get();
          allDocs.push(...batchSnap.docs);
        }
        studentDocs = { docs: allDocs };
        break;

      // Multiple visibility support (new feature)
      case "dept_year":
        studentDocs = await query
          .where("department", "==", notice.targetDepartment)
          .where("year", "==", notice.targetYear)
          .get();
        break;

      default:
        console.log("Unknown visibility:", notice.visibility);
        return null;
    }

    const students = studentDocs.docs;
    console.log(`Found ${students.length} eligible students`);

    if (students.length === 0) return null;

    // Collect all FCM tokens
    const tokens = [];
    for (const studentDoc of students) {
      const student = studentDoc.data();
      if (student.fcmToken && student.fcmToken.length > 0) {
        tokens.push(student.fcmToken);
      }
    }

    console.log(`Found ${tokens.length} FCM tokens`);

    if (tokens.length === 0) {
      console.log("No FCM tokens found — students may not have opened the app yet");
      return null;
    }

    // Send in batches of 500 (FCM limit per request)
    const batchSize = 500;
    for (let i = 0; i < tokens.length; i += batchSize) {
      const tokenBatch = tokens.slice(i, i + batchSize);

      const message = {
        notification: {
          title: notificationTitle,
          body:  notificationBody,
        },
        data: {
          noticeId:   noticeId,
          type:       "notice",
          priority:   notice.priority || "medium",
          category:   notice.category || "General",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          notification: {
            channelId: "college_notices",
            priority:  notice.priority === "urgent" ? "max" : "high",
            sound:     "default",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
        tokens: tokenBatch,
      };

      try {
        const response = await admin.messaging().sendEachForMulticast(message);
        console.log(`Sent to batch ${i / batchSize + 1}: ${response.successCount} success, ${response.failureCount} failed`);

        // Clean up invalid tokens
        if (response.failureCount > 0) {
          const failedTokens = [];
          response.responses.forEach((resp, idx) => {
            if (!resp.success) {
              const code = resp.error?.code;
              if (
                code === "messaging/invalid-registration-token" ||
                code === "messaging/registration-token-not-registered"
              ) {
                failedTokens.push(tokenBatch[idx]);
              }
            }
          });
          // Remove stale tokens from Firestore
          if (failedTokens.length > 0) {
            const cleanupBatch = db.batch();
            for (const staleToken of failedTokens) {
              const snap = await db.collection("users")
                .where("fcmToken", "==", staleToken)
                .limit(1)
                .get();
              snap.docs.forEach(doc =>
                cleanupBatch.update(doc.ref, { fcmToken: admin.firestore.FieldValue.delete() })
              );
            }
            await cleanupBatch.commit();
            console.log(`Cleaned up ${failedTokens.length} stale tokens`);
          }
        }
      } catch (error) {
        console.error("Error sending notifications:", error);
      }
    }

    return null;
  });