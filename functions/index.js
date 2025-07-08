const {onDocumentCreated, onDocumentUpdated} = require('firebase-functions/v2/firestore');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Cloud Function triggered when a walk is created
 * Sends push notifications to co-parents for real-time widget updates
 */
exports.onWalkCreated = onDocumentCreated('walks/{walkId}', async (event) => {
        const snap = event.data;
        if (!snap) {
            console.log('No data associated with the event');
            return;
        }
        
        const walkData = snap.data();
        
        console.log(`🚶‍♂️ Walk created: ${walkId}`, walkData);
        
        try {
            // Get the dog ID from the walk data
            const dogId = walkData.dogID;
            if (!dogId) {
                console.error('❌ No dogID found in walk data');
                return;
            }
            
            // Get dog information to determine if it's shared
            const dogDoc = await db.collection('dogs').doc(dogId).get();
            if (!dogDoc.exists) {
                console.log(`⚠️ Dog ${dogId} not found, skipping notifications`);
                return;
            }
            
            const dogData = dogDoc.data();
            const isShared = dogData.isShared || false;
            
            if (!isShared) {
                console.log(`ℹ️ Dog ${dogId} is not shared, skipping notifications`);
                return;
            }
            
            // Get all users who have access to this dog
            const shareQuery = await db.collection('shares')
                .where('dogID', '==', dogId)
                .where('isAccepted', '==', true)
                .get();
            
            if (shareQuery.empty) {
                console.log(`ℹ️ No accepted shares found for dog ${dogId}`);
                return;
            }
            
            // Get the walk owner information
            const ownerName = walkData.ownerName || dogData.ownerName || 'Someone';
            
            // Send push notifications to all co-parents
            const notifications = [];
            shareQuery.docs.forEach(doc => {
                const shareData = doc.data();
                notifications.push(
                    sendWalkNotification(shareData.sharedWithEmail, walkData, dogData, ownerName)
                );
            });
            
            // Also notify the dog owner if they're not the one who logged the walk
            if (dogData.ownerEmail && dogData.ownerEmail !== walkData.loggedByEmail) {
                notifications.push(
                    sendWalkNotification(dogData.ownerEmail, walkData, dogData, ownerName)
                );
            }
            
            await Promise.all(notifications);
            console.log(`✅ Sent ${notifications.length} walk notifications`);
            
        } catch (error) {
            console.error('❌ Error processing walk creation:', error);
        }
    });

/**
 * Cloud Function triggered when a walk is updated
 * Sends push notifications for walk modifications
 */
exports.onWalkUpdated = onDocumentUpdated('walks/{walkId}', async (event) => {
        const walkId = event.params.walkId;
        const beforeData = event.data.before.data();
        const afterData = event.data.after.data();
        
        console.log(`🔄 Walk updated: ${walkId}`);
        
        // Only send notifications for significant changes
        const significantFields = ['walkType', 'date'];
        const hasSignificantChange = significantFields.some(field => 
            beforeData[field] !== afterData[field]
        );
        
        if (!hasSignificantChange) {
            console.log('ℹ️ No significant changes, skipping notifications');
            return;
        }
        
        // Reuse the same logic as onCreate but with update context
        try {
            const dogId = afterData.dogID;
            if (!dogId) return;
            
            const dogDoc = await db.collection('dogs').doc(dogId).get();
            if (!dogDoc.exists) return;
            
            const dogData = dogDoc.data();
            if (!dogData.isShared) return;
            
            const shareQuery = await db.collection('shares')
                .where('dogID', '==', dogId)
                .where('isAccepted', '==', true)
                .get();
            
            if (shareQuery.empty) return;
            
            const ownerName = afterData.ownerName || dogData.ownerName || 'Someone';
            
            const notifications = [];
            shareQuery.docs.forEach(doc => {
                const shareData = doc.data();
                notifications.push(
                    sendWalkNotification(shareData.sharedWithEmail, afterData, dogData, ownerName, true)
                );
            });
            
            await Promise.all(notifications);
            console.log(`✅ Sent ${notifications.length} walk update notifications`);
            
        } catch (error) {
            console.error('❌ Error processing walk update:', error);
        }
    });

/**
 * Sends a push notification to a specific user about a walk
 */
async function sendWalkNotification(userEmail, walkData, dogData, ownerName, isUpdate = false) {
    try {
        console.log(`📤 Sending notification to: ${userEmail}`);
        
        // Get the user's FCM tokens
        const userQuery = await db.collection('users')
            .where('email', '==', userEmail)
            .limit(1)
            .get();
        
        if (userQuery.empty) {
            console.log(`⚠️ User ${userEmail} not found, skipping notification`);
            return;
        }
        
        const userData = userQuery.docs[0].data();
        const fcmTokens = userData.fcmTokens || [];
        
        if (fcmTokens.length === 0) {
            console.log(`⚠️ No FCM tokens for user ${userEmail}`);
            return;
        }
        
        // Prepare notification data
        const walkType = walkData.walkType === 1 ? 'Walk + Poop' : 'Walk';
        const dogName = dogData.name || 'Your dog';
        
        const title = isUpdate ? 'Walk Updated' : 'New Walk Logged';
        const body = `${ownerName} ${isUpdate ? 'updated' : 'logged'} a ${walkType} for ${dogName}`;
        
        // Create the notification payload
        const payload = {
            notification: {
                title: title,
                body: body,
                sound: 'default'
            },
            data: {
                type: 'walk_update',
                dogID: walkData.dogID,
                walkID: walkData.id || '',
                walkType: walkData.walkType.toString(),
                timestamp: walkData.date ? walkData.date.toDate().toISOString() : new Date().toISOString(),
                ownerName: ownerName,
                isUpdate: isUpdate.toString(),
                priority: 'high' // High priority for widget updates
            },
            apns: {
                payload: {
                    aps: {
                        'content-available': 1, // Enable background processing
                        sound: 'default'
                    }
                }
            },
            android: {
                priority: 'high',
                data: {
                    type: 'walk_update',
                    dogID: walkData.dogID,
                    walkType: walkData.walkType.toString(),
                    timestamp: walkData.date ? walkData.date.toDate().toISOString() : new Date().toISOString()
                }
            }
        };
        
        // Send to all user's devices
        const messages = fcmTokens.map(token => ({
            ...payload,
            token: token
        }));
        
        if (messages.length > 0) {
            const response = await messaging.sendAll(messages);
            console.log(`✅ Notification sent to ${response.successCount}/${messages.length} devices for ${userEmail}`);
            
            // Clean up invalid tokens
            if (response.failureCount > 0) {
                const validTokens = [];
                response.responses.forEach((resp, idx) => {
                    if (resp.success) {
                        validTokens.push(fcmTokens[idx]);
                    } else {
                        console.log(`❌ Failed to send to token: ${resp.error?.message}`);
                    }
                });
                
                // Update user's FCM tokens to remove invalid ones
                if (validTokens.length !== fcmTokens.length) {
                    await userQuery.docs[0].ref.update({ fcmTokens: validTokens });
                    console.log(`🧹 Cleaned up invalid tokens for ${userEmail}`);
                }
            }
        }
        
    } catch (error) {
        console.error(`❌ Error sending notification to ${userEmail}:`, error);
    }
}

/**
 * Cloud Function to handle FCM token registration
 */
exports.registerFCMToken = onCall(async (request) => {
    // Verify authentication
    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Must be authenticated');
    }
    
    const { token } = request.data;
    const userEmail = request.auth.token.email;
    
    if (!token || !userEmail) {
        throw new HttpsError('invalid-argument', 'Token and email required');
    }
    
    try {
        // Find or create user document
        const userQuery = await db.collection('users')
            .where('email', '==', userEmail)
            .limit(1)
            .get();
        
        let userRef;
        if (userQuery.empty) {
            // Create new user document
            userRef = db.collection('users').doc();
            await userRef.set({
                email: userEmail,
                fcmTokens: [token],
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                lastUpdated: admin.firestore.FieldValue.serverTimestamp()
            });
        } else {
            // Update existing user document
            userRef = userQuery.docs[0].ref;
            const userData = userQuery.docs[0].data();
            const currentTokens = userData.fcmTokens || [];
            
            // Add token if not already present
            if (!currentTokens.includes(token)) {
                currentTokens.push(token);
                await userRef.update({
                    fcmTokens: currentTokens,
                    lastUpdated: admin.firestore.FieldValue.serverTimestamp()
                });
            }
        }
        
        console.log(`✅ FCM token registered for ${userEmail}`);
        return { success: true };
        
    } catch (error) {
        console.error('❌ Error registering FCM token:', error);
        throw new HttpsError('internal', 'Failed to register token');
    }
});

/**
 * Scheduled function to clean up old walks (optional)
 */
exports.cleanupOldWalks = onSchedule('every 24 hours', async () => {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - 90); // Keep walks for 90 days
    
    try {
        const oldWalksQuery = await db.collection('walks')
            .where('date', '<', cutoffDate)
            .limit(100) // Process in batches
            .get();
        
        if (oldWalksQuery.empty) {
            console.log('ℹ️ No old walks to clean up');
            return;
        }
        
        const batch = db.batch();
        oldWalksQuery.docs.forEach(doc => {
            batch.delete(doc.ref);
        });
        
        await batch.commit();
        console.log(`🧹 Cleaned up ${oldWalksQuery.docs.length} old walks`);
        
    } catch (error) {
        console.error('❌ Error cleaning up old walks:', error);
    }
}); 