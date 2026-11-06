import { initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore, Timestamp } from 'firebase-admin/firestore';
import { RekognitionClient, SearchFacesByImageCommand, IndexFacesCommand, CreateCollectionCommand } from '@aws-sdk/client-rekognition';
import * as crypto from 'crypto';
import { onRequest, onCall, HttpsError } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';

initializeApp();
const db = getFirestore();

const MAX_PORSI_WEEK = 4;
const MAX_PESANAN_WEEK = 2;
const RESERVATION_MINUTES = 10;

function weekKey(d = new Date()): string {
  // ISO week in Asia/Jakarta.
  const jakarta = new Date(d.toLocaleString('en-US', { timeZone: 'Asia/Jakarta' }));
  const date = new Date(Date.UTC(jakarta.getFullYear(), jakarta.getMonth(), jakarta.getDate()));
  const day = date.getUTCDay() || 7;
  date.setUTCDate(date.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1));
  const week = Math.ceil(((date.getTime() - yearStart.getTime()) / 86400000 + 1) / 7);
  return `${date.getUTCFullYear()}-W${String(week).padStart(2, '0')}`;
}

function requireAuth(req: any): string {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Masuk dengan Google dulu.');
  return uid;
}

function sha256(s: string): string {
  return crypto.createHash('sha256').update(s).digest('hex');
}

function midtransBase(): string {
  return (process.env.MIDTRANS_IS_PRODUCTION || '').toLowerCase() === 'true'
    ? 'https://api.midtrans.com'
    : 'https://api.sandbox.midtrans.com';
}

// ---------- createOrder ----------
export const createOrder = onCall({ region: 'asia-southeast1' }, async (request) => {
  const uid = requireAuth(request);
  const { listingId, quantity } = request.data || {};
  const qty = Number(quantity);
  if (!listingId || !Number.isInteger(qty) || qty < 1 || qty > 4) {
    throw new HttpsError('invalid-argument', 'Jumlah porsi tidak wajar (1..4).');
  }

  const profileRef = db.collection('profiles').doc(uid);
  const listingRef = db.collection('food_listings').doc(String(listingId));
  const week = weekKey();

  // We need face identity from profile first.
  const profileSnap = await profileRef.get();
  if (!profileSnap.exists) throw new HttpsError('failed-precondition', 'Profil belum tersedia.');
  const profile = profileSnap.data() as any;
  const faceId = profile.face_identity_id as string | undefined;
  if (!faceId || !profile.face_verified_at) {
    throw new HttpsError('failed-precondition', 'Verifikasi wajah diperlukan untuk kuota mingguan.');
  }
  const faceClaimRef = db.collection('face_identities').doc(faceId).collection('weekly_claims').doc(week);

  const token = crypto.randomUUID();
  const tokenHash = sha256(token);
  const reservationExpiresAt = new Date(Date.now() + RESERVATION_MINUTES * 60 * 1000);

  let createdOrderId = '';
  await db.runTransaction(async (tx) => {
    const listingSnap = await tx.get(listingRef);
    if (!listingSnap.exists) throw new HttpsError('not-found', 'Penawaran tidak ditemukan.');
    const listing = listingSnap.data() as any;
    if (listing.status !== 'tersedia') throw new HttpsError('failed-precondition', 'Penawaran tidak tersedia.');
    const available = Number(listing.quantity_available || 0);
    if (available < qty) throw new HttpsError('failed-precondition', `Stok tidak mencukupi (tersisa ${available}).`);
    const end = (listing.pickup_end as Timestamp)?.toDate?.() || new Date(listing.pickup_end);
    if (!(end instanceof Date) || end.getTime() <= Date.now()) throw new HttpsError('failed-precondition', 'Waktu pengambilan sudah berakhir.');

    // Face weekly quota check.
    const claimSnap = await tx.get(faceClaimRef);
    const claim = claimSnap.exists ? (claimSnap.data() as any) : { porsi: 0, pesanan: 0, order_ids: [] };
    if ((claim.porsi || 0) + qty > MAX_PORSI_WEEK) throw new HttpsError('resource-exhausted', 'Kuota porsi mingguan wajah tercapai.');
    if ((claim.pesanan || 0) + 1 > MAX_PESANAN_WEEK) throw new HttpsError('resource-exhausted', 'Kuota pesanan mingguan wajah tercapai.');

    const orderId = db.collection('orders').doc().id;
    const orderRef = db.collection('orders').doc(orderId);
    const reservationRef = db.collection('reservations').doc(orderId);

    tx.update(listingRef, {
      quantity_available: available - qty,
      updated_at: FieldValue.serverTimestamp(),
    });

    tx.set(orderRef, {
      recipient_id: uid,
      store_id: listing.store_id,
      store_owner_id: listing.owner_id,
      listing_id: listingId,
      listing_title: listing.title,
      listing_category: listing.category,
      listing_image: listing.image_url || null,
      store_name: listing.store_name || '',
      quantity: qty,
      unit_price: listing.price_rupiah || 0,
      total_price: (listing.price_rupiah || 0) * qty,
      status: 'menunggu',
      payment_status: (listing.price_rupiah || 0) === 0 ? 'tidak_perlu' : 'belum_dibayar',
      pickup_token_hash: tokenHash,
      reservation_expires_at: Timestamp.fromDate(reservationExpiresAt),
      created_at: FieldValue.serverTimestamp(),
      updated_at: FieldValue.serverTimestamp(),
    });

    tx.set(reservationRef, {
      order_id: orderId,
      listing_id: listingId,
      store_id: listing.store_id,
      quantity: qty,
      status: 'aktif',
      expires_at: Timestamp.fromDate(reservationExpiresAt),
      created_at: FieldValue.serverTimestamp(),
      updated_at: FieldValue.serverTimestamp(),
    });

    tx.set(faceClaimRef, {
      porsi: (claim.porsi || 0) + qty,
      pesanan: (claim.pesanan || 0) + 1,
      order_ids: FieldValue.arrayUnion([orderId]),
      updated_at: FieldValue.serverTimestamp(),
    }, { merge: true });

    tx.update(profileRef, {
      weekly_porsi: (claim.porsi || 0) + qty,
      weekly_pesanan: (claim.pesanan || 0) + 1,
      updated_at: FieldValue.serverTimestamp(),
    });

    createdOrderId = orderId;
  });

  const orderId = createdOrderId;
  await db.collection('pickup_tokens').doc(orderId).set({
    token,
    created_at: FieldValue.serverTimestamp(),
  });
  // Note: token plaintext is returned once; server stores only hash in orders.

  return {
    orderId,
    pickupToken: token,
    reservationExpiresAt: reservationExpiresAt.toISOString(),
  };
});

// ---------- claimPickup ----------
export const claimPickup = onCall({ region: 'asia-southeast1' }, async (request) => {
  const uid = requireAuth(request);
  const { storeId, token } = request.data || {};
  if (!storeId || !token) throw new HttpsError('invalid-argument', 'Data pengambilan tidak lengkap.');

  const hash = sha256(String(token).trim().toUpperCase());
  const q = await db.collection('orders')
    .where('store_id', '==', storeId)
    .where('pickup_token_hash', '==', hash)
    .limit(1).get();
  if (q.empty) throw new HttpsError('not-found', 'Kode pengambilan tidak valid.');
  const orderDoc = q.docs[0];
  const order = orderDoc.data() as any;
  if (order.store_owner_id !== uid) throw new HttpsError('permission-denied', 'Pesanan bukan milik toko Anda.');
  if (['selesai','dibatalkan'].includes(order.status)) throw new HttpsError('failed-precondition', 'Pesanan sudah ditutup (QR bekas tidak berlaku).');

  await orderDoc.ref.update({
    status: 'selesai',
    picked_up_at: FieldValue.serverTimestamp(),
    pickup_verified: true,
    updated_at: FieldValue.serverTimestamp(),
  });
  const resRef = db.collection('reservations').doc(orderDoc.id);
  await resRef.set({ status: 'tuntas', updated_at: FieldValue.serverTimestamp() }, { merge: true });

  return { ok: true, message: 'Pengambilan terverifikasi di server.', orderId: orderDoc.id };
});

// ---------- nearbyListings ----------
export const nearbyListings = onCall({ region: 'asia-southeast1' }, async (request) => {
  requireAuth(request);
  const { lat, lng, radiusM = 8000, limit = 50 } = request.data || {};
  // Firestore has no native geo; return recent available listings and let client filter distance.
  const snap = await db.collection('food_listings')
    .where('status', '==', 'tersedia')
    .orderBy('pickup_end', 'asc')
    .limit(Math.min(Number(limit) * 2, 200))
    .get();
  const listings = snap.docs.map(d => ({ id: d.id, ...d.data(), distanceM: 0 }));
  return { listings };
});

// ---------- createStore ----------
export const createStore = onCall({ region: 'asia-southeast1' }, async (request) => {
  const uid = requireAuth(request);
  const d = request.data || {};
  const ref = db.collection('stores').doc();
  const store = {
    owner_id: uid,
    name: String(d.name || '').trim(),
    business_type: String(d.businessType || 'lainnya'),
    business_number: String(d.businessNumber || ''),
    phone: String(d.phone || ''),
    address: String(d.address || ''),
    city: String(d.city || ''),
    verification_status: 'menunggu_review',
    application: {
      business_number: String(d.businessNumber || ''),
      phone: String(d.phone || ''),
      photo_prepared: !!d.photoPrepared,
      location_prepared: !!d.locationPrepared,
    },
    created_at: FieldValue.serverTimestamp(),
    updated_at: FieldValue.serverTimestamp(),
  };
  await ref.set(store);
  return { storeId: ref.id, store };
});

// ---------- Face verification (AWS Rekognition OR on-device embedding) ----------
// Two paths:
//  - `data.embedding`: client-computed TFLite embedding (no AWS needed).
//    The server does 1:N cosine matching over `face_embeddings` in Firestore.
//  - `data.imageBase64`: AWS Rekognition search/index (requires AWS creds).
function rekognition(): RekognitionClient | null {
  if (!process.env.AWS_REGION || !process.env.AWS_ACCESS_KEY_ID) return null;
  return new RekognitionClient({ region: process.env.AWS_REGION });
}

// Cosine threshold tuned for MobileFaceNet-style normalized embeddings.
// Lower = more permissive. Tune per pilot data (FAR/FRR).
const FACE_EMBED_MATCH_THRESHOLD = Number(process.env.FACE_EMBED_MATCH_THRESHOLD || '0.42');

function normalizeVector(v: number[]): number[] {
  let norm = 0;
  for (const x of v) norm += x * x;
  norm = Math.sqrt(norm);
  if (!isFinite(norm) || norm <= 0) throw new HttpsError('invalid-argument', 'Wajah belum dapat diproses. Coba lagi.');
  return v.map((x) => x / norm);
}

function cosine(a: number[], b: number[]): number {
  let dot = 0;
  let na = 0;
  let nb = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  return dot / (Math.sqrt(na) * Math.sqrt(nb) || 1);
}

async function verifyFaceByEmbedding(uid: string, rawVec: unknown) {
  if (!Array.isArray(rawVec) || rawVec.length < 64 || rawVec.length > 1024) {
    throw new HttpsError('invalid-argument', 'Wajah belum dapat diproses. Coba lagi.');
  }
  const vec = normalizeVector(rawVec.map(Number));
  if (vec.some((x) => !isFinite(x))) {
    throw new HttpsError('invalid-argument', 'Wajah belum dapat diproses. Coba lagi.');
  }

  // 1:N match against stored templates. Honesty note: fine at pilot scale;
  // at thousands of identities this scan must move to a vector index.
  const snap = await db.collection('face_embeddings').get();
  let faceId = '';
  let existing = false;
  let score: number | null = null;
  let storedDoc: FirebaseFirestore.QueryDocumentSnapshot | null = null;
  for (const doc of snap.docs) {
    const data = doc.data() as any;
    const stored = Array.isArray(data?.vector) ? (data.vector as number[]) : null;
    if (!stored || stored.length !== vec.length) continue;
    const sim = cosine(vec, stored);
    if (sim >= FACE_EMBED_MATCH_THRESHOLD && sim > (score ?? -1)) {
      score = sim;
      faceId = doc.id;
      existing = true;
      storedDoc = doc;
    }
  }

  if (!faceId) {
    // New identity: random id, owned by this account.
    faceId = `emb_${crypto.randomBytes(12).toString('hex')}`;
    existing = false;
    score = null;
  }

  const batch = db.batch();
  const now = new Date();
  if (storedDoc) {
    // Refresh the vector only when the owner checks in (stability), never
    // overwrite a template owned by someone else.
    const data = storedDoc.data() as any;
    if (data?.ownerUid === uid) {
      const mixed = normalizeVector(
        vec.map((x, i) => x + (data.vector[i] ?? 0) * 0.05),
      );
      batch.set(db.collection('face_embeddings').doc(faceId), {
        ownerUid: uid,
        vector: mixed,
        updated_at: FieldValue.serverTimestamp(),
      }, { merge: true });
    }
  } else {
    batch.set(db.collection('face_embeddings').doc(faceId), {
      ownerUid: uid,
      vector: vec,
      created_at: FieldValue.serverTimestamp(),
      updated_at: FieldValue.serverTimestamp(),
    });
    batch.set(db.collection('face_identities').doc(faceId), {
      ownerUid: uid,
      method: 'on-device-embedding',
      created_at: FieldValue.serverTimestamp(),
    });
  }
  batch.set(db.collection('profiles').doc(uid), {
    face_identity_id: faceId,
    face_verified_at: Timestamp.fromDate(now),
    updated_at: FieldValue.serverTimestamp(),
  }, { merge: true });
  await batch.commit();

  const week = weekKey(now);
  const claimRef = db.collection('face_identities').doc(faceId).collection('weekly_claims').doc(week);
  const claimSnap = await claimRef.get();
  const claim = claimSnap.exists ? (claimSnap.data() as any) : { porsi: 0, pesanan: 0 };

  return {
    faceId,
    verifiedAt: now.toISOString(),
    matchScore: score,
    existingFace: existing,
    weeklyPorsi: claim.porsi || 0,
    weeklyPesanan: claim.pesanan || 0,
    maxPorsiPerWeek: MAX_PORSI_WEEK,
    maxPesananPerWeek: MAX_PESANAN_WEEK,
    weekKey: week,
  };
}

export const verifyFace = onCall({ region: 'asia-southeast1' }, async (request) => {
  const uid = requireAuth(request);
  const data = request.data || {};

  if ('embedding' in data && data.embedding) {
    return verifyFaceByEmbedding(uid, data.embedding);
  }

  const { imageBase64 } = data;
  if (!imageBase64) throw new HttpsError('invalid-argument', 'Foto selfie kosong.');

  const collectionId = process.env.AWS_REKOGNITION_COLLECTION || 'panganputar-faces';
  const rek = rekognition();
  if (!rek) throw new HttpsError('failed-precondition', 'Verifikasi wajah belum dikonfigurasi di server. Hubungi pengelola.');

  const bytes = Buffer.from(String(imageBase64), 'base64');
  // Ensure collection exists (idempotent-ish).
  try { await rek.send(new CreateCollectionCommand({ CollectionId: collectionId })); } catch (_) {}

  // Search first.
  let faceId = '';
  let existing = false;
  let score: number | null = null;
  try {
    const search = await rek.send(new SearchFacesByImageCommand({
      CollectionId: collectionId,
      Image: { Bytes: bytes },
      FaceMatchThreshold: 90,
      MaxFaces: 1,
    }));
    const match = search.FaceMatches?.[0];
    if (match?.Face?.FaceId) {
      faceId = match.Face.FaceId!;
      existing = true;
      score = (match.Similarity || 0) / 100;
    }
  } catch (_) {}

  if (!faceId) {
    const indexed = await rek.send(new IndexFacesCommand({
      CollectionId: collectionId,
      Image: { Bytes: bytes },
      MaxFaces: 1,
      QualityFilter: 'AUTO',
      DetectionAttributes: ['DEFAULT'],
    }));
    faceId = indexed.FaceRecords?.[0]?.Face?.FaceId || '';
    if (!faceId) throw new HttpsError('failed-precondition', 'Wajah tidak terdeteksi. Coba selfie ulang.');
  }

  const now = new Date();
  const profileRef = db.collection('profiles').doc(uid);
  await profileRef.set({
    face_identity_id: faceId,
    face_verified_at: Timestamp.fromDate(now),
    updated_at: FieldValue.serverTimestamp(),
  }, { merge: true });

  const week = weekKey(now);
  const claimRef = db.collection('face_identities').doc(faceId).collection('weekly_claims').doc(week);
  const claimSnap = await claimRef.get();
  const claim = claimSnap.exists ? (claimSnap.data() as any) : { porsi: 0, pesanan: 0 };

  return {
    faceId,
    verifiedAt: now.toISOString(),
    matchScore: score,
    existingFace: existing,
    weeklyPorsi: claim.porsi || 0,
    weeklyPesanan: claim.pesanan || 0,
    maxPorsiPerWeek: MAX_PORSI_WEEK,
    maxPesananPerWeek: MAX_PESANAN_WEEK,
    weekKey: week,
  };
});

export const faceStatus = onCall({ region: 'asia-southeast1' }, async (request) => {
  const uid = requireAuth(request);
  const profileSnap = await db.collection('profiles').doc(uid).get();
  if (!profileSnap.exists) return { faceId: null };
  const profile = profileSnap.data() as any;
  const faceId = profile.face_identity_id as string | undefined;
  if (!faceId) return { faceId: null };
  const week = weekKey();
  const claimSnap = await db.collection('face_identities').doc(faceId).collection('weekly_claims').doc(week).get();
  const claim = claimSnap.exists ? (claimSnap.data() as any) : { porsi: 0, pesanan: 0 };
  return {
    faceId,
    verifiedAt: profile.face_verified_at?.toDate?.()?.toISOString?.() || null,
    existingFace: true,
    weeklyPorsi: claim.porsi || 0,
    weeklyPesanan: claim.pesanan || 0,
    maxPorsiPerWeek: MAX_PORSI_WEEK,
    maxPesananPerWeek: MAX_PESANAN_WEEK,
    weekKey: week,
  };
});

// ---------- Payments (Midtrans) ----------
export const paymentsSnap = onCall({ region: 'asia-southeast1' }, async (request) => {
  const uid = requireAuth(request);
  const { orderId } = request.data || {};
  if (!orderId) throw new HttpsError('invalid-argument', 'orderId wajib.');

  const orderRef = db.collection('orders').doc(String(orderId));
  const orderSnap = await orderRef.get();
  if (!orderSnap.exists) throw new HttpsError('not-found', 'Pesanan tidak ditemukan.');
  const order = orderSnap.data() as any;
  if (order.recipient_id !== uid) throw new HttpsError('permission-denied', 'Pesanan ini bukan milik akun Anda.');
  if (order.payment_status === 'dibayar') throw new HttpsError('failed-precondition', 'Pesanan sudah dibayar.');
  if (order.status === 'dibatalkan') throw new HttpsError('failed-precondition', 'Pesanan dibatalkan.');

  const serverKey = process.env.MIDTRANS_SERVER_KEY;
  if (!serverKey) throw new HttpsError('failed-precondition', 'Midtrans server key belum dikonfigurasi.');

  const isProd = (process.env.MIDTRANS_IS_PRODUCTION || '').toLowerCase() === 'true';
  const base = isProd ? 'https://app.midtrans.com' : 'https://app.sandbox.midtrans.com';
  const authHeader = 'Basic ' + Buffer.from(serverKey + ':').toString('base64');

  const grossAmount = Number(order.total_price || 0);
  const payload = {
    transaction_details: { order_id: orderId, gross_amount: grossAmount },
    item_details: [{ id: order.listing_id, price: order.unit_price, quantity: order.quantity, name: order.listing_title }],
    customer_details: { first_name: 'Penerima PanganPutar' },
    expiry: { unit: 'minute', duration: RESERVATION_MINUTES },
  };

  const res = await fetch(`${base}/snap/v1/transactions`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': authHeader },
    body: JSON.stringify(payload),
  });
  if (!res.ok) throw new HttpsError('unavailable', 'Sesi pembayaran belum dapat dibuat.');
  const data: any = await res.json();
  const token = data.token as string;
  const redirectUrl = data.redirect_url as string;
  if (!token || !redirectUrl) throw new HttpsError('unavailable', 'Respons Midtrans tidak lengkap.');

  await db.collection('payments').doc(String(orderId)).set({
    order_id: orderId,
    gross_amount: grossAmount,
    status: 'menunggu',
    created_at: FieldValue.serverTimestamp(),
    updated_at: FieldValue.serverTimestamp(),
  }, { merge: true });

  return { token, redirectUrl, expiry: new Date(Date.now() + RESERVATION_MINUTES * 60 * 1000).toISOString() };
});

export const paymentsStatus = onCall({ region: 'asia-southeast1' }, async (request) => {
  const uid = requireAuth(request);
  const { orderId } = request.data || {};
  if (!orderId) throw new HttpsError('invalid-argument', 'orderId wajib.');
  const orderRef = db.collection('orders').doc(String(orderId));
  const orderSnap = await orderRef.get();
  if (!orderSnap.exists) throw new HttpsError('not-found', 'Pesanan tidak ditemukan.');
  const order = orderSnap.data() as any;
  if (order.recipient_id !== uid) throw new HttpsError('permission-denied', 'Pesanan ini bukan milik akun Anda.');

  const serverKey = process.env.MIDTRANS_SERVER_KEY;
  if (!serverKey) throw new HttpsError('failed-precondition', 'Midtrans server key belum dikonfigurasi.');
  const isProd = (process.env.MIDTRANS_IS_PRODUCTION || '').toLowerCase() === 'true';
  const base = isProd ? 'https://api.midtrans.com' : 'https://api.sandbox.midtrans.com';
  const authHeader = 'Basic ' + Buffer.from(serverKey + ':').toString('base64');

  const res = await fetch(`${base}/v2/${orderId}/status`, {
    headers: { 'Authorization': authHeader },
  });
  if (!res.ok) throw new HttpsError('unavailable', 'Status pembayaran belum dapat dicek.');
  const data: any = await res.json();
  const transactionStatus = String(data.transaction_status || '');
  const status = transactionStatus === 'settlement' || transactionStatus === 'capture'
    ? 'dibayar'
    : transactionStatus === 'pending' ? 'menunggu'
    : ['deny','cancel','failure'].includes(transactionStatus) ? 'gagal'
    : transactionStatus === 'expire' ? 'kedaluwarsa' : 'belum_dibayar';

  return {
    status,
    grossAmount: Number(data.gross_amount || order.total_price || 0),
    metode: data.payment_type || null,
    transactionId: data.transaction_id || null,
    paidAt: data.settlement_time || null,
  };
});

export const paymentsWebhook = onRequest({ region: 'asia-southeast1' }, async (req, res) => {
  if (req.method !== 'POST') { res.status(405).send('method not allowed'); return; }
  const body: any = req.body || {};
  const serverKey = process.env.MIDTRANS_SERVER_KEY || '';
  const expected = crypto.createHash('sha512')
    .update(String(body.order_id || '') + String(body.status_code || '') + String(body.gross_amount || '') + serverKey)
    .digest('hex');
  if (expected !== body.signature_key) { res.status(403).send('bad signature'); return; }

  // Re-GET official status.
  const isProd = (process.env.MIDTRANS_IS_PRODUCTION || '').toLowerCase() === 'true';
  const base = isProd ? 'https://api.midtrans.com' : 'https://api.sandbox.midtrans.com';
  const authHeader = 'Basic ' + Buffer.from(serverKey + ':').toString('base64');
  const officialRes = await fetch(`${base}/v2/${body.order_id}/status`, { headers: { 'Authorization': authHeader } });
  if (!officialRes.ok) { res.status(502).send('cannot verify'); return; }
  const official: any = await officialRes.json();
  const ts = String(official.transaction_status || '');

  const orderRef = db.collection('orders').doc(String(body.order_id));
  const orderSnap = await orderRef.get();
  if (!orderSnap.exists) { res.status(404).send('order not found'); return; }
  const order = orderSnap.data() as any;

  // Idempotent + no backward transitions.
  if (order.payment_status === 'dibayar') { res.status(200).send('already paid'); return; }

  if (ts === 'settlement' || ts === 'capture') {
    await orderRef.update({
      payment_status: 'dibayar',
      status: order.status === 'menunggu' ? 'dikonfirmasi' : order.status,
      updated_at: FieldValue.serverTimestamp(),
    });
    await db.collection('reservations').doc(String(body.order_id)).set({ status: 'tuntas', updated_at: FieldValue.serverTimestamp() }, { merge: true });
  } else if (ts === 'pending') {
    await orderRef.update({ payment_status: 'menunggu', updated_at: FieldValue.serverTimestamp() });
  } else if (['deny','cancel','failure'].includes(ts)) {
    await orderRef.update({ payment_status: 'gagal', status: 'dibatalkan', updated_at: FieldValue.serverTimestamp() });
    await db.collection('reservations').doc(String(body.order_id)).set({ status: 'dilepas', updated_at: FieldValue.serverTimestamp() }, { merge: true });
    // restore stock
    const listingRef = db.collection('food_listings').doc(order.listing_id);
    await listingRef.update({ quantity_available: FieldValue.increment(order.quantity), updated_at: FieldValue.serverTimestamp() });
  } else if (ts === 'expire') {
    await orderRef.update({ payment_status: 'kedaluwarsa', status: 'dibatalkan', updated_at: FieldValue.serverTimestamp() });
    await db.collection('reservations').doc(String(body.order_id)).set({ status: 'kadaluwarsa', updated_at: FieldValue.serverTimestamp() }, { merge: true });
    const listingRef = db.collection('food_listings').doc(order.listing_id);
    await listingRef.update({ quantity_available: FieldValue.increment(order.quantity), updated_at: FieldValue.serverTimestamp() });
  }

  res.status(200).send('ok');
});

// ---------- scheduled expiry ----------
export const expireReservations = onSchedule({ schedule: 'every 1 minutes', region: 'asia-southeast1' }, async () => {
  const now = Timestamp.now();
  const snap = await db.collection('reservations').where('status', '==', 'aktif').where('expires_at', '<=', now).get();
  for (const doc of snap.docs) {
    const r = doc.data() as any;
    await doc.ref.update({ status: 'kadaluwarsa', updated_at: FieldValue.serverTimestamp() });
    const orderRef = db.collection('orders').doc(r.order_id);
    const orderSnap = await orderRef.get();
    if (orderSnap.exists) {
      const order = orderSnap.data() as any;
      if (order.payment_status === 'belum_dibayar' || order.payment_status === 'menunggu') {
        await orderRef.update({ status: 'dibatalkan', payment_status: 'kedaluwarsa', updated_at: FieldValue.serverTimestamp() });
        const listingRef = db.collection('food_listings').doc(r.listing_id);
        await listingRef.update({ quantity_available: FieldValue.increment(r.quantity), updated_at: FieldValue.serverTimestamp() });
      }
    }
  }
});

