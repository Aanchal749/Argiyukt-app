import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

// ✅ SECURITY: Converts buffer to hex for exact signature matching
const bufferToHex = (buffer: ArrayBuffer): string => {
  return Array.from(new Uint8Array(buffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
};

// ✅ SECURITY: Cryptographically verifies the request came from Razorpay
const verifyRazorpaySignature = async (body: string, signature: string, secret: string): Promise<boolean> => {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signatureBuffer = await crypto.subtle.sign("HMAC", key, encoder.encode(body));
  const expectedSignature = bufferToHex(signatureBuffer);
  return expectedSignature === signature;
};

Deno.serve(async (req: Request) => {
  try {
    // Only accept POST requests
    if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

    const signature = req.headers.get("x-razorpay-signature");
    if (!signature) return new Response("Missing signature", { status: 400 });

    const bodyText = await req.text();
    
    // Asks the server for the secret you set in the terminal earlier.
    const webhookSecret = Deno.env.get("RAZORPAY_WEBHOOK_SECRET");

    if (!webhookSecret) {
      console.error("🚨 Missing RAZORPAY_WEBHOOK_SECRET environment variable");
      return new Response("Server config error", { status: 500 });
    }

    // 🔒 Enforce Security Check
    const isValid = await verifyRazorpaySignature(bodyText, signature, webhookSecret);
    if (!isValid) {
      console.error("🚨 ALERT: Invalid Razorpay Signature Detected!");
      return new Response("Unauthorized", { status: 401 });
    }

    const payload = JSON.parse(bodyText);

    // 🎯 Only listen for successfully cleared payments
    if (payload.event === "payment.captured") {
      const payment = payload.payload.payment.entity;
      
      // Extract the notes we sent from the Flutter App
      const appOrderId = payment.notes?.app_order_id;
      const farmerId = payment.notes?.farmer_id;
      const amountPaid = payment.amount / 100; // Razorpay sends amount in paise (cents)
      const transactionId = payment.id;

      if (!appOrderId) {
        return new Response("No app_order_id attached. Ignoring.", { status: 200 });
      }

      // ✅ PROD FIX: Explicitly mapped to YOUR EXACT Supabase Project URL!
      const supabaseUrl = "https://lyrbnrazuxjilbhdylwt.supabase.co";
      
      // ✅ PROD FIX: Supabase servers automatically hold the SUPABASE_SERVICE_ROLE_KEY. 
      const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
      const supabase = createClient(supabaseUrl, supabaseKey);

      // 🛡️ IDEMPOTENCY CHECK: Did we already process this exact transaction?
      const { data: existingPayment } = await supabase
        .from('payments')
        .select('id')
        .eq('gateway_transaction_id', transactionId)
        .maybeSingle();

      if (existingPayment) {
        console.log(`✅ Transaction ${transactionId} already processed. Skipping.`);
        return new Response("Already processed", { status: 200 });
      }

      console.log(`💰 Background Webhook Processing Payment: ${transactionId} for Order: ${appOrderId}`);

      // 1️⃣ Insert into Payments Table
      await supabase.from('payments').insert({
        order_id: appOrderId,
        buyer_id: payment.notes?.buyer_id || null, 
        farmer_id: farmerId,
        base_amount: amountPaid, 
        platform_fee: amountPaid * 0.04, // 4% Platform Fee
        total_charged: amountPaid + (amountPaid * 0.04),
        status: 'SUCCESS',
        payment_type: 'ONLINE',
        gateway_transaction_id: transactionId,
      });

      // 2️⃣ Get the current advance amount from the order safely
      const { data: orderData } = await supabase
        .from('orders')
        .select('advance_amount')
        .eq('id', appOrderId)
        .maybeSingle();

      const currentAdvance = orderData?.advance_amount || 0;
      const newTotal = currentAdvance + amountPaid;

      // 3️⃣ Update the Order Table
      await supabase
        .from('orders')
        .update({ advance_amount: newTotal })
        .eq('id', appOrderId);

      console.log(`🎉 Background Webhook Successfully updated Order ${appOrderId} with amount ${newTotal}`);
    }

    // Always return 200 OK so Razorpay knows we received it
    return new Response("Webhook processed", { status: 200 });
  } catch (err) {
    console.error("Server Error:", err);
    return new Response("Internal Server Error", { status: 500 });
  }
});