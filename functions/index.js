const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Cloud Function: onReminderCreated
 * 
 * Triggered when a new reminder is created
 * Creates notification jobs for each reminder
 */
exports.onReminderCreated = functions.firestore
  .document('reminders/{reminderId}')
  .onCreate(async (snap, context) => {
    const reminder = snap.data();
    const reminderId = context.params.reminderId;
    
    functions.logger.info(`Processing reminder: ${reminderId}`, { reminder });
    
    try {
      // Get event details
      const eventDoc = await db.collection('events').doc(reminder.eventId).get();
      if (!eventDoc.exists) {
        functions.logger.warn(`Event not found: ${reminder.eventId}`);
        return null;
      }
      
      const event = eventDoc.data();
      
      // Calculate notification time
      const eventTime = new Date(event.startTime);
      let notificationTime = new Date(eventTime);
      
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
          functions.logger.error(`Invalid reminder unit: ${reminder.unit}`);
          return null;
      }
      
      // Only create jobs for future notifications
      if (notificationTime <= new Date()) {
        functions.logger.info(`Notification time in past, skipping: ${notificationTime}`);
        return null;
      }
      
      // Get recipients
      const recipientUserIds = reminder.recipientUserIds || [];
      if (recipientUserIds.length === 0) {
        functions.logger.warn('No recipients specified');
        return null;
      }
      
      // Create notification jobs for each recipient
      const batch = db.batch();
      const jobsCreated = [];
      
      for (const userId of recipientUserIds) {
        const jobRef = db.collection('notification_jobs').doc();
        const job = {
          reminderId: reminderId,
          eventId: reminder.eventId,
          recipientUserId: userId,
          scheduledTime: admin.firestore.Timestamp.fromDate(notificationTime),
          status: 'pending',
          title: `Reminder: ${event.title}`,
          body: `Event starting in ${reminder.value} ${reminder.unit}`,
          data: {
            eventId: reminder.eventId,
            type: 'reminder',
          },
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        
        batch.set(jobRef, job);
        jobsCreated.push(jobRef.id);
      }
      
      await batch.commit();
      functions.logger.info(`Created ${jobsCreated.length} notification jobs`);
      
      return { success: true, jobsCreated: jobsCreated.length };
    } catch (error) {
      functions.logger.error('Error processing reminder:', error);
      return { success: false, error: error.message };
    }
  });

/**
 * Cloud Function: sendScheduledNotifications
 * 
 * Scheduled to run every 5 minutes
 * Sends notifications for jobs that are due
 */
exports.sendScheduledNotifications = functions.pubsub
  .schedule('every 5 minutes')
  .timeZone('Asia/Ho_Chi_Minh')
  .onRun(async (context) => {
    functions.logger.info('Starting scheduled notification job');
    
    try {
      const now = admin.firestore.Timestamp.now();
      
      // Query pending jobs that are due
      const jobsSnapshot = await db.collection('notification_jobs')
        .where('status', '==', 'pending')
        .where('scheduledTime', '<=', now)
        .limit(100) // Process 100 at a time
        .get();
      
      if (jobsSnapshot.empty) {
        functions.logger.info('No pending notifications to send');
        return null;
      }
      
      functions.logger.info(`Found ${jobsSnapshot.size} notifications to send`);
      
      const batch = db.batch();
      const sendPromises = [];
      
      for (const jobDoc of jobsSnapshot.docs) {
        const job = jobDoc.data();
        const jobRef = jobDoc.ref;
        
        // Get user's FCM token
        const userDoc = await db.collection('users').doc(job.recipientUserId).get();
        if (!userDoc.exists) {
          functions.logger.warn(`User not found: ${job.recipientUserId}`);
          batch.update(jobRef, {
            status: 'failed',
            error: 'User not found',
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          continue;
        }
        
        const user = userDoc.data();
        if (!user.fcmToken) {
          functions.logger.warn(`No FCM token for user: ${job.recipientUserId}`);
          batch.update(jobRef, {
            status: 'failed',
            error: 'No FCM token',
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          continue;
        }
        
        // Prepare notification
        const message = {
          notification: {
            title: job.title,
            body: job.body,
          },
          data: job.data || {},
          token: user.fcmToken,
        };
        
        // Send notification
        const sendPromise = messaging.send(message)
          .then((messageId) => {
            functions.logger.info(`Notification sent: ${messageId}`);
            batch.update(jobRef, {
              status: 'sent',
              messageId: messageId,
              processedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          })
          .catch((error) => {
            functions.logger.error(`Failed to send notification:`, error);
            batch.update(jobRef, {
              status: 'failed',
              error: error.message,
              processedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          });
        
        sendPromises.push(sendPromise);
      }
      
      // Wait for all notifications to be sent
      await Promise.all(sendPromises);
      
      // Commit batch updates
      await batch.commit();
      
      functions.logger.info('Scheduled notification job completed');
      return { success: true, processed: jobsSnapshot.size };
    } catch (error) {
      functions.logger.error('Error in scheduled job:', error);
      return { success: false, error: error.message };
    }
  });

/**
 * Cloud Function: cleanupOldNotifications
 * 
 * Scheduled to run daily at 2 AM
 * Removes old notification jobs (older than 7 days)
 */
exports.cleanupOldNotifications = functions.pubsub
  .schedule('every day 02:00')
  .timeZone('Asia/Ho_Chi_Minh')
  .onRun(async (context) => {
    functions.logger.info('Starting cleanup job');
    
    try {
      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
      const cutoffTime = admin.firestore.Timestamp.fromDate(sevenDaysAgo);
      
      // Query old jobs
      const oldJobsSnapshot = await db.collection('notification_jobs')
        .where('processedAt', '<=', cutoffTime)
        .limit(500) // Delete 500 at a time
        .get();
      
      if (oldJobsSnapshot.empty) {
        functions.logger.info('No old notifications to clean up');
        return null;
      }
      
      functions.logger.info(`Deleting ${oldJobsSnapshot.size} old notifications`);
      
      const batch = db.batch();
      oldJobsSnapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });
      
      await batch.commit();
      
      functions.logger.info('Cleanup job completed');
      return { success: true, deleted: oldJobsSnapshot.size };
    } catch (error) {
      functions.logger.error('Error in cleanup job:', error);
      return { success: false, error: error.message };
    }
  });

/**
 * Cloud Function: onUserApproved
 * 
 * Triggered when a user's role changes from pending
 * Sends a welcome notification
 */
exports.onUserApproved = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const userId = context.params.userId;
    
    // Check if user was approved (role changed from pending)
    if (before.role === 'pending' && after.role !== 'pending') {
      functions.logger.info(`User approved: ${userId}, role: ${after.role}`);
      
      // If user has FCM token, send welcome notification
      if (after.fcmToken) {
        const message = {
          notification: {
            title: 'Account Approved! 🎉',
            body: `Welcome to CG Calendar! You've been approved as ${getRoleName(after.role)}.`,
          },
          data: {
            type: 'approval',
            role: after.role,
          },
          token: after.fcmToken,
        };
        
        try {
          const messageId = await messaging.send(message);
          functions.logger.info(`Welcome notification sent: ${messageId}`);
        } catch (error) {
          functions.logger.error('Failed to send welcome notification:', error);
        }
      }
    }
    
    return null;
  });

/**
 * Helper function to get role display name
 */
function getRoleName(role) {
  switch (role) {
    case 'viewer':
      return 'Viewer';
    case 'editor':
      return 'Editor';
    case 'super_editor':
      return 'Super Editor';
    default:
      return 'User';
  }
}
