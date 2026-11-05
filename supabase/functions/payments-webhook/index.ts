// PanganPutar — Edge Function: payments-webhook (tahap 6)
// NOTIF HTTP Midtrans → keputusan uang (TIDAK BISA dipanggil klien).
//
// Deploy: supabase functions deploy payments-webhook --no-verify-jwt
//   (Midtrans memanggil tanpa JWT — sah hanya karena env ini yang
//   memverifikasi signature). Pasang di Midtrans Dashboard:
//   Settings → Payment Notification URL =
//   https://<proj>.supabase.co/functions/v1/payments-webhook
//
// Aturan wajib rencana, semua ditegakkan di sini:
// 1. signature_key = sha512(order_id + status_code + gross_amount + key);
//    beda → 403, tidak ada mutasi.
// 2. KONFIRMASI ULANG ke Midtrans (GET status API) sebelum mengubah
//    order — payload notifikasi tidak dipercaya mentah. GET gagal →
//    502 tanpa mutasi (Midtrans akan mengulang).
// 3. Idempotent + tanpa transisi mundur: order sudah dibayar tidak boleh
//    dibatalkan oleh notifikasi berikutnya; order sudah dibatalkan/gagal
//    tidak dibangkitkan jadi dibayar. Semua event dicatat ke
//    `payment_events` (audit, termasuk yang diabaikan).
// 4. Pemetaan: capture/settlement(capture fraud=accept) → dibayar;
//    pending → menunggu; deny/cancel/failure/expire → gagal/kedaluwarsa,
//    lepas reservasi; refund/partial_refund → dicatat, dijawab noop
//    (refund kena endpoint server terpisah — JUJUR: belum dibangun).
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

const serverKey = Deno.env.get('MIDTRANS_SERVER_KEY') ?? '';
const midtransApi = (Deno.env.get('MIDTRANS_IS_PRODUCTION') || '').toLowerCase() === 'true'
  ? 'https://api.midtrans.com'
  : 'https://api.sandbox.midtrans.com';

function db(): SupabaseClient {
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  );
}

async function sha512Hex(text: string): Promise<string> {
  const data = new TextEncoder().encode(text);
  const digest = await crypto.subtle.digest('SHA-512', data);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

// Re-GET status resmi Midtrans (bukan payload mentah).
async function statusMidtrans(orderId: string): Promise<{
  transaction_status: string;
  fraud_status: string | null;
  transaction_id: string;
  payment_type: string | null;
  gross_amount: string;
  transaction_time: string | null;
} | null> {
  const r = await fetch(`${midtransApi}/v2/${orderId}/status`, {
    headers: {
      Authorization: `Basic ${btoa(`${serverKey}:`)}`,
      Accept: 'application/json',
    },
  });
  if (!r.ok) return null;
  return await r.json() as never;
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'metode tidak didukung' }, 405);

  let raw: Record<string, unknown>;
  let body: {
    order_id: string;
    status_code: string;
    gross_amount: string;
    signature_key: string;
    transaction_status: string;
    transaction_id: string;
    payment_type: string;
    fraud_status: string;
    transaction_time: string;
  };
  try {
    raw = await req.json();
    body = raw as never;
  } catch {
    return json({ error: 'isi JSON tidak terbaca' }, 400);
  }

  const { order_id, status_code, gross_amount, signature_key } = body;
  if (!order_id || !signature_key) {
    return json({ error: 'isi notifikasi tidak lengkap' }, 400);
  }
  const duga = await sha512Hex(
    `${order_id}${status_code}${gross_amount}${serverKey}`,
  );
  if (duga !== signature_key.toLowerCase()) {
    return json({ error: 'tanda tangan tidak sah' }, 403);
  }

  const client = db();

  // 2. Konfirmasi ulang ke Midtrans. Payload notifikasi boleh memicu —
  //    mutasi hanya lewat hasil GET status API.
  const m = await statusMidtrans(order_id);
  const statusSah = m?.transaction_status ?? body.transaction_status;
  if (!m) {
    // Log audit tetap (berguna saat insiden Midtrans), tetapi TANPA mutasi.
    await client.from('payment_events').insert({
      order_id,
      transaction_status: body.transaction_status,
      transaction_id: body.transaction_id ?? null,
      payment_type: body.payment_type ?? null,
      gross_amount: gross_amount ? Number(gross_amount) : null,
      raw,
    });
    return json({ error: 'Midtrans status API tidak terjangkau — mutasi ditunda' }, 502);
  }

  // 4. Pemetaan & guard transisi.
  type Aksi = 'finalize' | 'fail' | 'noop';
  const peta: Record<string, Aksi> = {
    capture: 'finalize', // fraud_status accept diperiksa di bawah
    settlement: 'finalize',
    pending: 'noop',           // tetap menunggu
    deny: 'fail',
    cancel: 'fail',
    expire: 'fail',            // kedaluwarsa MIDTRANS ↔ kedaluwarsa reservasi
    failure: 'fail',
    refund: 'noop',            // refund kena endpoint terpisah (belum dibangun)
    partial_refund: 'noop',
  };
  let aksi = peta[statusSah] ?? 'noop';
  // capture BISA di-reject Midtrans fraud; accept saja final.
  if (statusSah === 'capture' && (m.fraud_status ?? 'accept') !== 'accept') {
    aksi = 'noop'; // challenge/deny fraud → tunggu settlement/deny selanjutnya
  }

  // Audit SEBELUM mutasi (juga bila noop) — semua event ketemu jejaknya.
  const tersimpan = await client.from('payment_events').insert({
    order_id,
    transaction_status: statusSah,
    transaction_id: m.transaction_id ?? null,
    payment_type: m.payment_type ?? null,
    gross_amount: Number(m.gross_amount),
    raw,
  });

  // Tanpa transisi mundur:
  const { data: order } = await client
    .from('orders')
    .select('payment_status, status')
    .eq('id', order_id)
    .maybeSingle();
  const kini = order?.payment_status ?? 'belum_dibayar';
  if (aksi === 'fail' && kini === 'dibayar') {
    return json({ ok: true, aksi: 'ditolak-mundur', idempoten: true });
  }
  if (aksi === 'finalize' && (kini === 'gagal' || order?.status === 'dibatalkan')) {
    return json({ ok: true, aksi: 'ditolak-mundur', idempoten: true });
  }
  if (aksi === 'noop') {
    return json({ ok: true, aksi: 'dingin', idempoten: true });
  }

  try {
    const rpc = aksi === 'finalize' ? 'finalize_paid_order' : 'fail_payment_order';
    const { error } = await client.rpc(rpc, { p_order_id: order_id });
    if (error) {
      // Menulis mutasi dua kali (idempotensi) = bukan galat untuk Midtrans.
      if (error.message.includes('kandidat')) {
        return json({ ok: true, aksi: 'idempoten' });
      }
      return json({ error: error.message }, 500);
    }

    // Perbarui baris payments (metode, referensi gateway, jejak raw).
    const statusDb = aksi === 'finalize'
      ? 'dibayar'
      : (statusSah === 'expire' ? 'kedaluwarsa' : 'gagal');
    await client
      .from('payments')
      .update({
        status: statusDb,
        method: m.payment_type ?? body.payment_type,
        gateway_reference: m.transaction_id,
        raw_notification: raw,
      })
      .eq('order_id', order_id);

    // payment_id di event tadi isi (payments ada sekarang).
    const { data: baris } = await client
      .from('payments')
      .select('id')
      .eq('order_id', order_id)
      .limit(1)
      .maybeSingle();
    if (baris?.id && ('data' in tersimpan)) {
      await client
        .from('payment_events')
        .update({ payment_id: baris.id })
        .eq('order_id', order_id)
        .is('payment_id', null)
        .order('created_at', { ascending: false })
        .limit(1);
    }

    return json({ ok: true, aksi });
  } catch (e) {
    return json({ error: `${e}` }, 500);
  }
});
