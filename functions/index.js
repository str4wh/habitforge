const { onSchedule }   = require('firebase-functions/v2/scheduler');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore }  = require('firebase-admin/firestore');
const { getMessaging }  = require('firebase-admin/messaging');

initializeApp();

// ── Helpers ───────────────────────────────────────────────────────────────────

function getTodayNairobi() {
  // Nairobi = UTC+3, no DST
  const d = new Date(Date.now() + 3 * 3600 * 1000);
  return d.toISOString().split('T')[0]; // yyyy-MM-dd
}

async function sendNotification(body) {
  const db        = getFirestore();
  const messaging = getMessaging();
  const today     = getTodayNairobi();

  const usersSnap = await db.collection('users').get();

  for (const userDoc of usersSnap.docs) {
    const uid = userDoc.id;

    const [tokenDoc, logDoc, habitsSnap] = await Promise.all([
      db.collection('users').doc(uid).collection('meta').doc('fcmToken').get(),
      db.collection('users').doc(uid).collection('logs').doc(today).get(),
      db.collection('users').doc(uid).collection('habits')
        .where('isActive', '==', true).get(),
    ]);

    // No token registered — skip
    if (!tokenDoc.exists || !tokenDoc.data().token) continue;

    // All habits done — skip this notification
    const activeCount = habitsSnap.size;
    const doneCount   = logDoc.exists
      ? (logDoc.data().completedHabits || []).length
      : 0;
    if (activeCount > 0 && doneCount >= activeCount) continue;

    const token = tokenDoc.data().token;

    try {
      await messaging.send({
        token,
        notification: {
          title: 'HabitForge',
          body,
        },
        webpush: {
          notification: {
            icon:               '/icons/Icon-192.png',
            badge:              '/icons/Icon-192.png',
            tag:                'habitforge-daily',
            renotify:           true,
            requireInteraction: false,
          },
          fcmOptions: {
            link: 'https://jitumenani.netlify.app',
          },
        },
      });
    } catch (err) {
      // Stale token — clean it up so we don't retry forever
      if (
        err.code === 'messaging/registration-token-not-registered' ||
        err.code === 'messaging/invalid-registration-token'
      ) {
        await db.collection('users').doc(uid)
          .collection('meta').doc('fcmToken').delete();
      }
    }
  }
}

// ── Scheduled notifications (Nairobi timezone) ────────────────────────────────

const opts = { timeZone: 'Africa/Nairobi', region: 'us-central1' };

exports.notify6am = onSchedule(
  { ...opts, schedule: '0 6 * * *' },
  () => sendNotification("You're awake. Now stop wasting the first hour of your day.")
);

exports.notify12pm = onSchedule(
  { ...opts, schedule: '0 12 * * *' },
  () => sendNotification("Halfway through the day. How many habits done? Be honest.")
);

exports.notify6pm = onSchedule(
  { ...opts, schedule: '0 18 * * *' },
  () => sendNotification("You have 2 hours before you run out of excuses for today.")
);

exports.notify9pm = onSchedule(
  { ...opts, schedule: '0 21 * * *' },
  () => sendNotification("You didn't finish today's habits did you? Log them anyway.")
);

exports.notify10pm = onSchedule(
  { ...opts, schedule: '0 22 * * *' },
  () => sendNotification("Another day gone. Was it worth it or did you just survive it?")
);
