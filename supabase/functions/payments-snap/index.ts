// PanganPutar — Edge Function: payments-snap (tahap 6)
// Buat transaksi Midtrans Snap. SERVER KEY tinggal di env ini.
// Deploy: supabase functions deploy payments-snap
// Env (project): MIDTRANS_SERVER_KEY, MIDTRANS_IS_PRODUCTION,
//                SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (otomatis).
//
// Semua aturan dari prompt (pembayaran midtrans):
// - `expiry` = masa reservasi (10 menit, sama seperti create_order) supaya
//   itu Midtrans kedaluwarsa pada momen yang sama dengan reservasi.
// - `item_details` dinyatakan oleh SERVER (judul + harga listing), bukan
//   biaya dari klien. Nominal juga dihitung dari total_rupiah, bukan
//   dari payload.
// - Mode sandbox dengan tanda jelas: env MIDTRANS_IS_PRODUCTION=false
//   memakai app.sandbox.midtrans.com.
//
// Semantik:
// - Wajib JWT Supabase milik PEMBELI (header Authorization Bearer).
// - Pesanan harus miliknya, berbayar, belum dibayar, belum dibatalkan,
//   dan nominal HARUS sama dengan total di server (gross_amount tidak
//   bisa diubah dari payload klien).
// - Menulis baris payments (status 'menunggu') untuk jejak; resolusi
//   final tetap dari webhook payments-webhook.
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

const midtransBase = (Deno.env.get('MIDTRANS_IS_PRODUCTION') || '').toLowerCase() === 'true'
  ? 'https://app.midtrans.com'
  : 'https://app.sandbox.midtrans.com';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS },
  });
}

function admin(): SupabaseClient {
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  );
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ error: 'metode tidak didukung' }, 405);

  const bearer = (req.headers.get('Authorization') || '').replace(/^Bearer /i, '');
  if (!bearer) return json({ error: 'wajib JWT pembeli' }, 401);

  const userClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    (req.headers.get('apikey') || bearer),
    { global: { headers: { Authorization: `Bearer ${bearer}` } } },
  );
  const { data: auth } = await userClient.auth.getUser(bearer);
  const uid = auth?.user?.id;
  if (!uid) return json({ error: 'JWT tidak sah' }, 401);

  let body: { orderId?: string; grossAmount?: number; deviceId?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'isi JSON tidak terbaca' }, 400);
  }
  const orderId = String(body.orderId || '');
  const grossAmount = Number(body.grossAmount || 0);
  if (!orderId || !Number.isFinite(grossAmount) || grossAmount <= 0) {
    return json({ error: 'orderId / grossAmount tidak wajar' }, 400);
  }

  const db = admin();
  const { data: order, error: dbErr } = await db
    .from('orders')
    .select(`
      id, recipient_id, total_rupiah, quantity, status, payment_status,
      listing_id, store_id
    `)
    .eq('id', orderId)
    .maybeSingle();
  if (dbErr) return json({ error: dbErr.message }, 500);
  if (
    !order ||
    order.recipient_id !== uid ||
    order.payment_status !== 'belum_dibayar' ||
    order.status === 'dibatalkan'
  ) {
    return json({ error: 'pesanan tidak bisa diproses' }, 403);
  }
  if (order.total_rupiah !== grossAmount) {
    // Jangan pernah menerima nominal dari klien — jaga dari pembayaran
    // sisa 1 rupiah yang jadi milik (jujur: nominal dari server).
    return json({ error: 'nominal tidak sama dengan server' }, 400);
  }

  // item_details DARI SERVER (bukan kembalian klien) — judul listing.
  const { data: listing } = await db
    .from('food_listings')
    .select('title, price_rupiah')
    .eq('id', order.listing_id)
    .eq('store_id', order.store_id)
    .maybeSingle();

  const snapUrl = `${midtransBase}/snap/v1/transactions`;
  const r = await fetch(snapUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      Authorization: `Basic ${btoa(`${Deno.env.get('MIDTRANS_SERVER_KEY')!}:`)}`,
    },
    body: JSON.stringify({
      transaction_details: {
        order_id: orderId,
        gross_amount: grossAmount,
      },
      item_details: [{
        id: order.listing_id,
        name: (listing?.title || 'Pesanan PanganPutar').slice(0, 50),
        price: listing?.price_rupiah ?? Math.floor(grossAmount / (order.quantity || 1)),
        quantity: order.quantity || 1,
      }],
      customer_details: {
        first_name: 'Penerima PanganPutar',
        // Tidak ada identitas sensitif; sengaja tidak kirim data tambahan.
      },
      // Expiry = masa reservasi (create_order = 10 menit). Midtrans dan
      // reservasi kedaluwarsa pada momen yang sama — tidak ada celah.
      expiry: { unit: 'minutes', duration: 10 },
      callbacks: { finish: 'demo_app' },
    }),
  });
  if (!r.ok) {
    const text = await r.text();
    return json({ error: `Midtrans ${r.status}: ${text}` }, 502);
  }
  const snap = await r.json() as { token: string; redirect_url: string };

  const { error: payErr } = await db.from('payments').insert({
    order_id: orderId,
    amount_rupiah: grossAmount,
    status: 'menunggu',
    method: 'midtrans_snap',
  });
  if (payErr) {
    // Snap sudah dibuat; jangan gagalkan pembayarannya. Webhook akan
    // menentukan keputusan final berdasarkan data Midtrans.
    console.error('gagal simpan payments:', payErr.message);
  }

  return json({ token: snap.token, redirect_url: snap.redirect_url });
});
