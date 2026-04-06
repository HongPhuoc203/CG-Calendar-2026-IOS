const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

/** Translate reminder unit to Vietnamese display label */
function getReminderLabel(value, unit) {
  const map = { minutes: 'phút', hours: 'giờ', days: 'ngày' };
  const unitVi = map[unit] || unit;
  return `${value} ${unitVi}`;
}

/** Helper function to get role display name in Vietnamese */
function getRoleName(role) {
  switch (role) {
    case 'viewer': return 'Viewer';
    case 'editor': return 'Editor';
    case 'super_editor': return 'Super Editor';
    default: return 'User';
  }
}

/**
 * Read fcmTokens (array) or fall back to legacy fcmToken (string).
 * Returns an array of token strings (may be empty).
 */
function extractTokens(userData) {
  if (Array.isArray(userData.fcmTokens) && userData.fcmTokens.length > 0) {
    return userData.fcmTokens;
  }
  if (userData.fcmToken) return [userData.fcmToken];
  return [];
}

/**
 * Send a multicast FCM message to a list of tokens.
 * Automatically removes invalid/expired tokens from Firestore.
 */
async function sendMulticast(tokens, notification, data, userId) {
  if (tokens.length === 0) return;

  const response = await messaging.sendEachForMulticast({ notification, data, tokens });
  functions_logger.info(
    `Multicast to user ${userId}: ${response.successCount} ok, ${response.failureCount} failed`
  );

  // Remove invalid tokens from Firestore
  const invalidTokens = [];
  response.responses.forEach((resp, idx) => {
    if (!resp.success) {
      const code = resp.error && resp.error.code;
      if (
        code === 'messaging/invalid-registration-token' ||
        code === 'messaging/registration-token-not-registered'
      ) {
        invalidTokens.push(tokens[idx]);
      }
    }
  });
  if (invalidTokens.length > 0) {
    await db.collection('users').doc(userId).update({
      fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
    }).catch((e) => functions_logger.error('Failed to remove invalid tokens:', e));
  }

  return response;
}

// Lazy logger reference (set after first use to avoid import issues)
let functions_logger;

// ─────────────────────────────────────────────────────────────
// Cloud Function: onReminderCreated
// Triggered when a new reminder document is created.
// Creates notification_jobs for each recipient.
// ─────────────────────────────────────────────────────────────
exports.onReminderCreated = onDocumentCreated(
  { document: 'reminders/{reminderId}', region: 'us-central1' },
  async (event) => {
    const { logger } = require('firebase-functions/v2');
    functions_logger = logger;

    const snap = event.data;
    const reminder = snap.data();
    const reminderId = event.params.reminderId;

    logger.info(`Processing reminder: ${reminderId}`);

    try {
      // Get event details
      const eventDoc = await db.collection('events').doc(reminder.eventId).get();
      if (!eventDoc.exists) {
        logger.warn(`Event not found: ${reminder.eventId}`);
        return null;
      }
      const ev = eventDoc.data();

      // Calculate notification time
      const eventTime = new Date(ev.startTime);
      const notificationTime = new Date(eventTime);
      switch (reminder.unit) {
        case 'minutes':
          notificationTime.setMinutes(notificationTime.getMinutes() - reminder.value);
          break;
        case 'hours':
          notificationTime.setHours(notificationTime.getHours() - reminder.value);
          break;
        case 'days':
          notificationTime.setDate(notificationTime.getDate() - reminder.value);
          break;
        default:
          logger.error(`Invalid reminder unit: ${reminder.unit}`);
          return null;
      }

      if (notificationTime <= new Date()) {
        logger.info(`Notification time in past, skipping: ${notificationTime}`);
        return null;
      }

      // Build Vietnamese notification content
      const reminderLabel = getReminderLabel(reminder.value, reminder.unit);
      const timeStr = `${String(eventTime.getHours()).padStart(2, '0')}:${String(eventTime.getMinutes()).padStart(2, '0')}`;
      const locationPart = ev.location ? ` • ${ev.location}` : '';
      const notifTitle = `⏰ ${ev.title}`;
      const notifBody = `Bắt đầu lúc ${timeStr} (còn ${reminderLabel})${locationPart}`;

      // Get recipients
      const recipientUserIds = reminder.recipientUserIds || [];
      if (recipientUserIds.length === 0) {
        logger.warn('No recipients specified');
        return null;
      }

      // Create one notification_job per recipient
      const batch = db.batch();
      for (const userId of recipientUserIds) {
        const jobRef = db.collection('notification_jobs').doc();
        batch.set(jobRef, {
          reminderId,
          eventId: reminder.eventId,
          recipientUserId: userId,
          scheduledTime: admin.firestore.Timestamp.fromDate(notificationTime),
          status: 'pending',
          title: notifTitle,
          body: notifBody,
          // reminderId included so FCMService can cancel the local alarm with the
          // same notification ID (reminderId.hashCode) before showing the FCM push,
          // preventing duplicate display on devices that have both paths active.
          data: { eventId: reminder.eventId, reminderId, type: 'reminder' },
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      logger.info(`Created ${recipientUserIds.length} notification jobs for reminder ${reminderId}`);
      return { success: true, jobsCreated: recipientUserIds.length };
    } catch (error) {
      logger.error('Error processing reminder:', error);
      return { success: false, error: error.message };
    }
  }
);

// ─────────────────────────────────────────────────────────────
// Cloud Function: sendScheduledNotifications
// Runs every 5 minutes. Sends FCM for all due notification_jobs.
// ─────────────────────────────────────────────────────────────
exports.sendScheduledNotifications = onSchedule(
  { schedule: 'every 5 minutes', timeZone: 'Asia/Ho_Chi_Minh', region: 'us-central1' },
  async () => {
    const { logger } = require('firebase-functions/v2');
    functions_logger = logger;

    // ── [1] START ─────────────────────────────────────────────────────────────
    const runId = Date.now(); // unique tag so interleaved runs are distinguishable
    logger.info(`[sendScheduledNotifications] ▶ Run started (runId: ${runId})`);

    try {
      const now = admin.firestore.Timestamp.now();
      logger.info(`[sendScheduledNotifications] Querying pending jobs with scheduledTime <= ${now.toDate().toISOString()}`);

      const jobsSnapshot = await db.collection('notification_jobs')
        .where('status', '==', 'pending')
        .where('scheduledTime', '<=', now)
        .limit(100)
        .get();

      if (jobsSnapshot.empty) {
        logger.info(`[sendScheduledNotifications] ✓ No pending jobs due. Exiting. (runId: ${runId})`);
        return null;
      }

      logger.info(`[sendScheduledNotifications] Found ${jobsSnapshot.size} due job(s). Processing... (runId: ${runId})`);

      const batch = db.batch();
      const sendPromises = [];

      for (const jobDoc of jobsSnapshot.docs) {
        const job = jobDoc.data();
        const jobRef = jobDoc.ref;
        const jobId = jobDoc.id;

        // ── [2] JOB INFO ────────────────────────────────────────────────────────
        logger.info(`[sendScheduledNotifications] ── Job: ${jobId}`, {
          jobId,
          recipientUserId: job.recipientUserId,
          eventId: job.eventId,
          type: job.data && job.data.type,
          title: job.title,
          scheduledTime: job.scheduledTime && job.scheduledTime.toDate
            ? job.scheduledTime.toDate().toISOString()
            : String(job.scheduledTime),
        });

        // ── [3] FETCH USER & TOKENS ─────────────────────────────────────────────
        logger.info(`[sendScheduledNotifications] Fetching user doc for: ${job.recipientUserId}`);
        const userDoc = await db.collection('users').doc(job.recipientUserId).get();

        if (!userDoc.exists) {
          logger.warn(`[sendScheduledNotifications] ✗ User not found in Firestore — userId: ${job.recipientUserId}. Marking job failed.`);
          batch.update(jobRef, {
            status: 'failed',
            error: 'User not found',
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          continue;
        }

        const userData = userDoc.data();
        const tokens = extractTokens(userData);

        // Log token source and count, with each token abbreviated for readability
        const tokenSource = Array.isArray(userData.fcmTokens) && userData.fcmTokens.length > 0
          ? 'fcmTokens (array)'
          : userData.fcmToken
            ? 'fcmToken (legacy string)'
            : 'none';
        const tokenPreviews = tokens.map((t, i) => `[${i}] ${t.substring(0, 20)}...${t.slice(-6)}`);

        logger.info(`[sendScheduledNotifications] User tokens resolved`, {
          userId: job.recipientUserId,
          email: userData.email || '(no email)',
          tokenSource,
          tokenCount: tokens.length,
          tokens: tokenPreviews,
        });

        if (tokens.length === 0) {
          logger.warn(`[sendScheduledNotifications] ✗ No FCM tokens for user: ${job.recipientUserId} (source field: ${tokenSource}). Marking job failed.`);
          batch.update(jobRef, {
            status: 'failed',
            error: 'No FCM token',
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          continue;
        }

        // ── [4] FCM SEND ────────────────────────────────────────────────────────
        const notification = { title: job.title, body: job.body };
        const data = job.data || {};

        logger.info(`[sendScheduledNotifications] Sending FCM multicast for job ${jobId}`, {
          userId: job.recipientUserId,
          tokenCount: tokens.length,
          notification,
        });

        const sendPromise = messaging.sendEachForMulticast({ notification, data, tokens })
          .then((response) => {
            // ── [5] PER-TOKEN RESULT ──────────────────────────────────────────────
            logger.info(`[sendScheduledNotifications] FCM response for job ${jobId}: ${response.successCount} succeeded, ${response.failureCount} failed`);

            const invalidTokens = [];

            response.responses.forEach((resp, idx) => {
              const tokenPreview = `${tokens[idx].substring(0, 20)}...${tokens[idx].slice(-6)}`;
              if (resp.success) {
                logger.info(`[sendScheduledNotifications]   ✔ Token[${idx}] delivered — userId: ${job.recipientUserId} | token: ${tokenPreview} | messageId: ${resp.messageId}`);
              } else {
                const errorCode = resp.error && resp.error.code;
                const errorMsg  = resp.error && resp.error.message;
                logger.warn(`[sendScheduledNotifications]   ✗ Token[${idx}] failed — userId: ${job.recipientUserId} | token: ${tokenPreview} | errorCode: ${errorCode} | errorMessage: ${errorMsg}`);

                if (
                  errorCode === 'messaging/invalid-registration-token' ||
                  errorCode === 'messaging/registration-token-not-registered'
                ) {
                  logger.warn(`[sendScheduledNotifications]   → Token[${idx}] is stale/invalid — will be removed from Firestore (userId: ${job.recipientUserId})`);
                  invalidTokens.push(tokens[idx]);
                }
              }
            });

            // Remove stale tokens from Firestore
            if (invalidTokens.length > 0) {
              logger.info(`[sendScheduledNotifications] Removing ${invalidTokens.length} invalid token(s) from userId: ${job.recipientUserId}`);
              db.collection('users').doc(job.recipientUserId).update({
                fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
              }).catch((e) => logger.error(`[sendScheduledNotifications] Failed to remove invalid tokens for userId ${job.recipientUserId}:`, e));
            }

            // ── [6] MARK JOB STATUS ───────────────────────────────────────────────
            const finalStatus = response.successCount > 0 ? 'sent' : 'failed';
            logger.info(`[sendScheduledNotifications] Marking job ${jobId} as '${finalStatus}'`);
            batch.update(jobRef, {
              status: finalStatus,
              error: response.successCount === 0 ? 'All tokens failed' : null,
              processedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          })
          .catch((error) => {
            logger.error(`[sendScheduledNotifications] ✗ sendEachForMulticast threw for job ${jobId}`, {
              jobId,
              userId: job.recipientUserId,
              message: error.message,
              stack: error.stack,
            });
            batch.update(jobRef, {
              status: 'failed',
              error: error.message,
              processedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          });

        sendPromises.push(sendPromise);
      }

      await Promise.all(sendPromises);
      await batch.commit();

      // ── [7] SUMMARY ───────────────────────────────────────────────────────────
      logger.info(`[sendScheduledNotifications] ✅ Run complete — ${jobsSnapshot.size} job(s) processed. (runId: ${runId})`);
      return { success: true, processed: jobsSnapshot.size };

    } catch (error) {
      logger.error(`[sendScheduledNotifications] ✗ Unhandled error (runId: ${runId})`, {
        message: error.message,
        stack: error.stack,
      });
      return { success: false, error: error.message };
    }
  }
);

// ─────────────────────────────────────────────────────────────
// Cloud Function: cleanupOldNotifications
// Runs daily at 02:00 Asia/Ho_Chi_Minh. Deletes jobs older than 7 days.
// ─────────────────────────────────────────────────────────────
exports.cleanupOldNotifications = onSchedule(
  { schedule: '0 2 * * *', timeZone: 'Asia/Ho_Chi_Minh', region: 'us-central1' },
  async () => {
    const { logger } = require('firebase-functions/v2');
    logger.info('Starting cleanup job');

    try {
      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
      const cutoffTime = admin.firestore.Timestamp.fromDate(sevenDaysAgo);

      const oldJobsSnapshot = await db.collection('notification_jobs')
        .where('processedAt', '<=', cutoffTime)
        .limit(500)
        .get();

      if (oldJobsSnapshot.empty) {
        logger.info('No old notifications to clean up');
        return null;
      }

      const batch = db.batch();
      oldJobsSnapshot.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();

      logger.info(`Cleanup: deleted ${oldJobsSnapshot.size} old notification jobs`);
      return { success: true, deleted: oldJobsSnapshot.size };
    } catch (error) {
      logger.error('Error in cleanup job:', error);
      return { success: false, error: error.message };
    }
  }
);

// ─────────────────────────────────────────────────────────────
// Cloud Function: onEventCreated
// Triggered when a new event document is created.
// Resolves recipients by role, writes in-app notifications
// and immediate notification_jobs for FCM delivery.
//
// Notification rules:
//   Super_editor creates:
//     • All super_editors (including creator)
//     • Editors who manage at least one artist in the event
//     • Viewers whose artistId is in the event's artistIds
//
//   Editor creates:
//     • All super_editors
//     • Viewers whose artistId is in the event's artistIds
// ─────────────────────────────────────────────────────────────
exports.onEventCreated = onDocumentCreated(
  { document: 'events/{eventId}', region: 'us-central1' },
  async (event) => {
    const { logger } = require('firebase-functions/v2');
    functions_logger = logger;

    // ── [1] TRIGGER ────────────────────────────────────────────────────────────
    const snap = event.data;
    const ev = snap.data();
    const eventId = event.params.eventId;

    logger.info('[onEventCreated] ▶ Function triggered', {
      eventId,
      title: ev.title,
      createdBy: ev.createdBy,
      artistIds: ev.artistIds || [],
      startTime: ev.startTime,
      location: ev.location || null,
    });

    try {
      // ── [2] CREATOR INFO ──────────────────────────────────────────────────────
      logger.info(`[onEventCreated] Fetching creator doc for userId: ${ev.createdBy}`);

      const creatorDoc = await db.collection('users').doc(ev.createdBy).get();
      if (!creatorDoc.exists) {
        logger.warn(`[onEventCreated] ✗ Creator document not found in Firestore (userId: ${ev.createdBy}). Aborting.`);
        return null;
      }

      const creatorData = creatorDoc.data();
      const creatorRole = creatorData.role;
      const eventArtistIds = ev.artistIds || [];

      logger.info('[onEventCreated] Creator resolved', {
        userId: ev.createdBy,
        role: creatorRole,
        email: creatorData.email || '(no email field)',
        status: creatorData.status || '(no status field)',
      });

      // ── [3] ROLE ROUTING ──────────────────────────────────────────────────────
      if (creatorRole !== 'super_editor' && creatorRole !== 'editor') {
        logger.info(`[onEventCreated] ⏭ Creator role '${creatorRole}' does not trigger event notifications. Skipping.`);
        return null;
      }

      if (creatorRole === 'super_editor') {
        logger.info('[onEventCreated] ── Case: Creator is Super_editor ──────────────────');
        logger.info(`[onEventCreated] Will notify: all super_editors (self + peers) | editors managing event artists | viewers linked to event artists`);
      } else {
        logger.info('[onEventCreated] ── Case: Creator is Editor ────────────────────────');
        logger.info(`[onEventCreated] Will notify: all super_editors | viewers linked to event artists`);
      }

      logger.info(`[onEventCreated] Event artistIds: [${eventArtistIds.join(', ')}]`);

      // ── [4] RECIPIENT RESOLUTION ──────────────────────────────────────────────
      logger.info('[onEventCreated] Firing role-targeted Firestore queries in parallel...');

      const [superEditorSnap, editorSnap, viewerSnap] = await Promise.all([
        // Always needed: super_editors receive notifications in both creator cases
        db.collection('users').where('role', '==', 'super_editor').get(),
        // Only needed when creator is super_editor (editors are not notified for editor-created events)
        creatorRole === 'super_editor'
          ? db.collection('users').where('role', '==', 'editor').get()
          : Promise.resolve({ docs: [] }),
        // Always needed: viewers linked to event artists receive notifications in both cases
        db.collection('users').where('role', '==', 'viewer').get(),
      ]);

      logger.info('[onEventCreated] Query results', {
        superEditors_found: superEditorSnap.docs.length,
        editors_found: creatorRole === 'super_editor' ? editorSnap.docs.length : '(not queried)',
        viewers_found: viewerSnap.docs.length,
      });

      const recipientIds = new Set();

      // ── All super_editors (self-notify for creator + all peers) ──────────────
      logger.info(`[onEventCreated] Processing ${superEditorSnap.docs.length} super_editor(s)...`);
      for (const doc of superEditorSnap.docs) {
        const alreadyIn = recipientIds.has(doc.id);
        recipientIds.add(doc.id);
        if (alreadyIn) {
          logger.info(`[onEventCreated] ⊘ Duplicate skipped — userId: ${doc.id} (super_editor)`);
        } else {
          logger.info(`[onEventCreated] ✔ Added super_editor — userId: ${doc.id}`);
        }
      }

      // ── Editors managing ≥1 event artist (super_editor creator only) ─────────
      if (creatorRole === 'super_editor') {
        logger.info(`[onEventCreated] Processing ${editorSnap.docs.length} editor(s) for artist overlap...`);
        let editorsAdded = 0;
        for (const doc of editorSnap.docs) {
          const managed = doc.data().managedArtistIds || [];
          const overlaps = managed.filter((id) => eventArtistIds.includes(id));
          if (overlaps.length > 0) {
            const alreadyIn = recipientIds.has(doc.id);
            recipientIds.add(doc.id);
            editorsAdded++;
            if (alreadyIn) {
              logger.info(`[onEventCreated] ⊘ Duplicate skipped — userId: ${doc.id} (editor, overlapping artists: [${overlaps.join(', ')}])`);
            } else {
              logger.info(`[onEventCreated] ✔ Added editor — userId: ${doc.id} | managedArtistIds: [${managed.join(', ')}] | overlapping: [${overlaps.join(', ')}]`);
            }
          } else {
            logger.info(`[onEventCreated] ✗ Editor skipped — userId: ${doc.id} | managedArtistIds: [${managed.join(', ')}] | no overlap with event artists`);
          }
        }
        logger.info(`[onEventCreated] Editors added to recipients: ${editorsAdded} / ${editorSnap.docs.length}`);
      }

      // ── Viewers whose linked artist is in this event (both creator roles) ────
      logger.info(`[onEventCreated] Processing ${viewerSnap.docs.length} viewer(s) for artist match...`);
      let viewersAdded = 0;
      for (const doc of viewerSnap.docs) {
        const artistId = doc.data().artistId;
        if (artistId && eventArtistIds.includes(artistId)) {
          const alreadyIn = recipientIds.has(doc.id);
          recipientIds.add(doc.id);
          viewersAdded++;
          if (alreadyIn) {
            logger.info(`[onEventCreated] ⊘ Duplicate skipped — userId: ${doc.id} (viewer, artistId: ${artistId})`);
          } else {
            logger.info(`[onEventCreated] ✔ Added viewer — userId: ${doc.id} | artistId: ${artistId}`);
          }
        } else {
          logger.info(`[onEventCreated] ✗ Viewer skipped — userId: ${doc.id} | artistId: ${artistId || '(none)'} | not in event artists`);
        }
      }
      logger.info(`[onEventCreated] Viewers added to recipients: ${viewersAdded} / ${viewerSnap.docs.length}`);

      // ── [5] FINAL RECIPIENT LIST ──────────────────────────────────────────────
      const recipientArray = Array.from(recipientIds);
      logger.info(`[onEventCreated] ── Final recipient list (${recipientArray.length} total) ──`, {
        recipientIds: recipientArray,
      });

      if (recipientArray.length === 0) {
        logger.info('[onEventCreated] ⚠ No recipients resolved. No notifications will be written.');
        return null;
      }

      // ── Build notification content ────────────────────────────────────────────
      const startTime = new Date(ev.startTime);
      const timeStr = `${String(startTime.getHours()).padStart(2, '0')}:${String(startTime.getMinutes()).padStart(2, '0')}`;
      const locationPart = ev.location ? ` • ${ev.location}` : '';
      const notifTitle = `📅 Sự kiện mới: ${ev.title}`;
      const notifBody = `Bắt đầu lúc ${timeStr}${locationPart}`;

      logger.info('[onEventCreated] Notification content', { title: notifTitle, body: notifBody });

      // ── [6] FIRESTORE WRITES (in-app notifications only, no FCM push) ─────────
      // FCM push notifications are handled exclusively by the reminder system
      // (onReminderCreated + sendScheduledNotifications). onEventCreated only
      // writes to the `notifications` collection for the in-app notification screen.
      const serverNow = admin.firestore.FieldValue.serverTimestamp();

      // Firestore batch limit is 500 ops; each recipient needs 1 write.
      // Process in chunks of 400 recipients to stay well under the limit.
      const CHUNK_SIZE = 400;
      const totalBatches = Math.ceil(recipientArray.length / CHUNK_SIZE);
      logger.info(`[onEventCreated] Writing in-app notifications in ${totalBatches} batch(es) (chunk size: ${CHUNK_SIZE})...`);

      for (let i = 0; i < recipientArray.length; i += CHUNK_SIZE) {
        const chunk = recipientArray.slice(i, i + CHUNK_SIZE);
        const batchIndex = Math.floor(i / CHUNK_SIZE) + 1;
        const batch = db.batch();

        logger.info(`[onEventCreated] Preparing batch ${batchIndex}/${totalBatches} — ${chunk.length} recipient(s): [${chunk.join(', ')}]`);

        for (const userId of chunk) {
          // In-app notification (shown in NotificationsScreen)
          const notifRef = db.collection('notifications').doc();
          batch.set(notifRef, {
            userId,
            title: notifTitle,
            body: notifBody,
            type: 'event_created',
            relatedId: eventId,
            isRead: false,
            createdAt: serverNow,
          });
        }

        await batch.commit();
        logger.info(`[onEventCreated] ✔ Batch ${batchIndex}/${totalBatches} committed — ${chunk.length} Firestore ops`);
      }

      logger.info(`[onEventCreated] ✅ In-app notifications written — ${recipientArray.length} recipient(s), ${totalBatches} batch(es), event: ${eventId}`);
      return { success: true, recipients: recipientArray.length };

    } catch (error) {
      // ── [7] ERROR HANDLING ────────────────────────────────────────────────────
      logger.error('[onEventCreated] ✗ Unhandled error', {
        message: error.message,
        stack: error.stack,
        eventId,
        createdBy: ev.createdBy,
      });
      return { success: false, error: error.message };
    }
  }
);

// ─────────────────────────────────────────────────────────────
// Cloud Function: onUserApproved
// Triggered when a user's role changes from 'pending'.
// Sends a welcome FCM notification.
// ─────────────────────────────────────────────────────────────
exports.onUserApproved = onDocumentUpdated(
  { document: 'users/{userId}', region: 'us-central1' },
  async (event) => {
    const { logger } = require('firebase-functions/v2');
    const before = event.data.before.data();
    const after = event.data.after.data();
    const userId = event.params.userId;

    if (before.role !== 'pending' || after.role === 'pending') return null;

    logger.info(`User approved: ${userId}, role: ${after.role}`);

    const tokens = extractTokens(after);
    if (tokens.length === 0) {
      logger.info(`No FCM tokens for newly approved user: ${userId}`);
      return null;
    }

    try {
      const response = await messaging.sendEachForMulticast({
        notification: {
          title: 'Tài khoản đã được duyệt! 🎉',
          body: `Chào mừng đến CG Calendar! Bạn đã được phê duyệt với vai trò ${getRoleName(after.role)}.`,
        },
        data: { type: 'approval', role: after.role },
        tokens,
      });
      logger.info(
        `Welcome notification: ${response.successCount} ok, ${response.failureCount} failed`
      );
    } catch (error) {
      logger.error('Failed to send welcome notification:', error);
    }

    return null;
  }
);
