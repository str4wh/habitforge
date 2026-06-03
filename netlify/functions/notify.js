/**
 * HabitForge — push notification sender
 *
 * Called by cron-job.org at each notification time (see README below).
 * Reads FCM tokens from Firestore, checks habit completion, sends push.
 *
 * Required env vars in Netlify dashboard:
 *   FIREBASE_PROJECT_ID     → habitforge-60e2e
 *   FIREBASE_CLIENT_EMAIL   → from service account JSON
 *   FIREBASE_PRIVATE_KEY    → from service account JSON  (paste the full -----BEGIN... key)
 *   NOTIFY_SECRET           → any strong random string you choose (same in cron-job.org header)
 */

const { initializeApp, cert, getApps } = require('firebase-admin/app');
const { getFirestore }                 = require('firebase-admin/firestore');
const { getMessaging }                 = require('firebase-admin/messaging');

// ── Messages keyed by Nairobi hour (UTC+3) ───────────────────────────────────
const MESSAGES = {
   6: "You're awake. Now stop wasting the first hour of your day.",
  12: "Halfway through the day. How many habits done? Be honest.",
  18: "You have 2 hours before you run out of excuses for today.",
  21: "You didn't finish today's habits did you? Log them anyway.",
  22: "Another day gone. Was it worth it or did you just survive it?",
};

// ── Firebase Admin singleton ──────────────────────────────────────────────────
function getFirebase() {
  if (getApps().length > 0) return getApps()[0];
  return initializeApp({
    credential: cert({
      projectId:   process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey:  process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
    }),
  });
}

// ── Date helpers (Nairobi = UTC+3, no DST) ────────────────────────────────────
function getNairobiHour() {
  return (new Date().getUTCHours() + 3) % 24;
}

function getTodayNairobi() {
  const d = new Date(Date.now() + 3 * 3600 * 1000);
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, '0');
  const day = String(d.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

// ── Handler ───────────────────────────────────────────────────────────────────
exports.handler = async (event) => {
  // 1. Authenticate the cron caller
  const secret =
    event.headers['x-notify-secret'] ??
    event.headers['authorization']?.replace('Bearer ', '');

  if (!secret || secret !== process.env.NOTIFY_SECRET) {
    return { statusCode: 401, body: 'Unauthorized' };
  }

  // 2. Resolve which message to send
  const hour    = getNairobiHour();
  const body    = MESSAGES[hour];
  if (!body) {
    return { statusCode: 200, body: `No notification scheduled for hour ${hour}` };
  }

  // 3. Init Firebase
  getFirebase();
  const db        = getFirestore();
  const messaging = getMessaging();
  const today     = getTodayNairobi();
  const results   = [];

  // 4. Process every registered user
  const usersSnap = await db.collection('users').get();

  for (const userDoc of usersSnap.docs) {
    const uid = userDoc.id;

    // Read token + today's log + active habits in parallel
    const [tokenDoc, logDoc, habitsSnap] = await Promise.all([
      db.collection('users').doc(uid).collection('meta').doc('fcmToken').get(),
      db.collection('users').doc(uid).collection('logs').doc(today).get(),
      db.collection('users').doc(uid).collection('habits')
        .where('isActive', '==', true).get(),
    ]);

    if (!tokenDoc.exists) { results.push({ uid, status: 'no_token' }); continue; }

    const token        = tokenDoc.data().token;
    const activeCount  = habitsSnap.size;
    const doneCount    = logDoc.exists
      ? (logDoc.data().completedHabits ?? []).length
      : 0;

    // Skip if everything is already done
    if (activeCount > 0 && doneCount >= activeCount) {
      results.push({ uid, status: 'skipped_all_done' });
      continue;
    }

    // 5. Send the push notification
    try {
      await messaging.send({
        token,
        notification: { title: 'HabitForge', body },
        webpush: {
          notification: {
            icon:               '/icons/Icon-192.png',
            badge:              '/icons/Icon-192.png',
            tag:                'habitforge-daily',
            renotify:           true,
            requireInteraction: false,
          },
          fcmOptions: { link: '/' },
        },
      });
      results.push({ uid, status: 'sent', hour });
    } catch (err) {
      // Invalid / expired token — clean up so we don't keep trying
      if (
        err.code === 'messaging/registration-token-not-registered' ||
        err.code === 'messaging/invalid-registration-token'
      ) {
        await db.collection('users').doc(uid).collection('meta')
          .doc('fcmToken').delete();
        results.push({ uid, status: 'token_removed' });
      } else {
        results.push({ uid, status: 'error', error: err.message });
      }
    }
  }

  return {
    statusCode: 200,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ ok: true, hour, message: body, results }),
  };
};
