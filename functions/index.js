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

// ── Savings velocity helpers ──────────────────────────────────────────────────

function getNairobiNow() {
  return new Date(Date.now() + 3 * 3600 * 1000);
}

function daysInMonthFor(year, month) {
  // month is 1-based; new Date(year, month, 0) gives last day of that month
  return new Date(year, month, 0).getDate();
}

async function sendSavingsVelocityNotifications() {
  const db        = getFirestore();
  const messaging = getMessaging();

  const now        = getNairobiNow();
  const year       = now.getUTCFullYear();
  const month      = now.getUTCMonth() + 1; // 1-based
  const dayOfMonth = now.getUTCDate();
  const totalDays  = daysInMonthFor(year, month);
  const daysRemaining = totalDays - dayOfMonth;

  const monthStart = `${year}-${String(month).padStart(2, '0')}-01`;
  const nextMonth  = month === 12 ? 1 : month + 1;
  const nextYear   = month === 12 ? year + 1 : year;
  const monthEnd   = `${nextYear}-${String(nextMonth).padStart(2, '0')}-01`;

  const usersSnap = await db.collection('users').get();

  for (const userDoc of usersSnap.docs) {
    const uid = userDoc.id;

    const [tokenDoc, targetDoc, logsSnap] = await Promise.all([
      db.collection('users').doc(uid).collection('meta').doc('fcmToken').get(),
      db.collection('users').doc(uid).collection('meta').doc('savingsTarget').get(),
      db.collection('users').doc(uid).collection('logs')
        .where('__name__', '>=', monthStart)
        .where('__name__', '<',  monthEnd)
        .get(),
    ]);

    // No token or no target set → skip
    if (!tokenDoc.exists || !tokenDoc.data().token) continue;
    if (!targetDoc.exists) continue;
    const target = targetDoc.data().target;
    if (!target || target <= 0) continue;

    const monthSaved = logsSnap.docs.reduce(
      (sum, doc) => sum + (doc.data().savingsAmount || 0), 0);

    const dailyAverage  = monthSaved / dayOfMonth;
    const projected     = dailyAverage * totalDays;

    // On track (within 90 % threshold) → no notification
    if (projected >= target * 0.9) continue;

    const dailyRequired = daysRemaining > 0
      ? Math.max(0, Math.round((target - monthSaved) / daysRemaining))
      : 0;

    const fmt = (n) => Math.round(n).toLocaleString('en-KE');

    const body = dayOfMonth < 15
      ? `You're behind on savings. At this rate you finish the month at KES ${fmt(projected)}, not KES ${fmt(target)}. You need KES ${dailyRequired.toLocaleString('en-KE')}/day for the rest of the month.`
      : `Past the halfway point and still behind on savings. KES ${fmt(target - projected)} short of your target. That's KES ${dailyRequired.toLocaleString('en-KE')}/day for the remaining ${daysRemaining} days. Stop spending.`;

    const token = tokenDoc.data().token;

    try {
      await messaging.send({
        token,
        notification: { title: 'HabitForge', body },
        webpush: {
          notification: {
            icon:               '/icons/Icon-192.png',
            badge:              '/icons/Icon-192.png',
            tag:                'habitforge-savings',
            renotify:           true,
            requireInteraction: false,
          },
          fcmOptions: { link: 'https://jitumenani.netlify.app' },
        },
      });
    } catch (err) {
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

exports.notify8pmSavings = onSchedule(
  { ...opts, schedule: '0 20 * * *' },
  () => sendSavingsVelocityNotifications()
);
