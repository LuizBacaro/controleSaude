import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }
  const secret = Deno.env.get("STRIPE_WEBHOOK_SECRET");
  const key = Deno.env.get("STRIPE_SECRET_KEY");
  if (!secret || !key) {
    return Response.json(
      { error: "O pagamento no site ainda não está configurado." },
      { status: 503 },
    );
  }

  const body = await req.text();
  const valid = await verifyStripe(
    body,
    req.headers.get("stripe-signature"),
    secret,
  );
  if (!valid) return Response.json({ error: "Assinatura inválida." }, { status: 400 });

  const event = JSON.parse(body) as {
    type?: string;
    data?: { object?: Record<string, unknown> };
  };
  const object = event.data?.object ?? {};
  const userId = await userIdOf(event.type ?? "", object, key);
  if (!userId) return Response.json({ received: true });

  const status = await statusOf(event.type ?? "", object, key);
  if (!status) return Response.json({ received: true });

  const admin = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );
  const { error } = await admin.from("doctor_subscriptions").upsert({
    user_id: userId,
    status: status.status,
    source: "web",
    current_period_end: status.periodEnd,
    updated_at: new Date().toISOString(),
  });
  if (error) return Response.json({ error: error.message }, { status: 500 });
  return Response.json({ received: true });
});

async function userIdOf(
  type: string,
  object: Record<string, unknown>,
  key: string,
): Promise<string | null> {
  const direct = metadataUser(object);
  if (direct) return direct;
  if (type === "checkout.session.completed") {
    const subscription = object.subscription;
    if (typeof subscription === "string") {
      return metadataUser(await stripeGet(key, `subscriptions/${subscription}`));
    }
  }
  if (type.startsWith("invoice.")) {
    const subscription = object.subscription;
    if (typeof subscription === "string") {
      return metadataUser(await stripeGet(key, `subscriptions/${subscription}`));
    }
  }
  return null;
}

async function statusOf(
  type: string,
  object: Record<string, unknown>,
  key: string,
): Promise<{ status: string; periodEnd: string | null } | null> {
  if (type === "checkout.session.completed") {
    const subscription = object.subscription;
    if (typeof subscription !== "string") {
      return { status: "active", periodEnd: null };
    }
    return mapSubscription(await stripeGet(key, `subscriptions/${subscription}`));
  }
  if (type === "customer.subscription.deleted") {
    return { status: "canceled", periodEnd: periodEndOf(object) };
  }
  if (
    type === "customer.subscription.updated" ||
    type === "customer.subscription.created"
  ) {
    return mapSubscription(object);
  }
  if (type === "invoice.paid") {
    const subscription = object.subscription;
    if (typeof subscription !== "string") return { status: "active", periodEnd: null };
    return mapSubscription(await stripeGet(key, `subscriptions/${subscription}`));
  }
  if (type === "invoice.payment_failed") {
    return { status: "past_due", periodEnd: null };
  }
  return null;
}

function mapSubscription(object: Record<string, unknown>) {
  const raw = typeof object.status === "string" ? object.status : "";
  const status = raw === "active" || raw === "trialing"
    ? "active"
    : raw === "past_due" || raw === "unpaid"
    ? "past_due"
    : raw === "canceled" || raw === "incomplete_expired"
    ? "canceled"
    : "inactive";
  return { status, periodEnd: periodEndOf(object) };
}

function periodEndOf(object: Record<string, unknown>): string | null {
  const end = object.current_period_end;
  if (typeof end !== "number") return null;
  return new Date(end * 1000).toISOString();
}

function metadataUser(object: Record<string, unknown>): string | null {
  const metadata = object.metadata;
  if (metadata && typeof metadata === "object" && "user_id" in metadata) {
    const id = (metadata as { user_id?: unknown }).user_id;
    if (typeof id === "string" && id.length > 0) return id;
  }
  const reference = object.client_reference_id;
  return typeof reference === "string" && reference.length > 0 ? reference : null;
}

async function stripeGet(key: string, path: string) {
  const response = await fetch(`https://api.stripe.com/v1/${path}`, {
    headers: { Authorization: `Bearer ${key}` },
  });
  return await response.json() as Record<string, unknown>;
}

async function verifyStripe(body: string, signature: string | null, secret: string) {
  if (!signature) return false;
  const parts = signature.split(",");
  const timestamp = parts.find((part) => part.startsWith("t="))?.slice(2);
  const signatures = parts
    .filter((part) => part.startsWith("v1="))
    .map((part) => part.slice(3));
  if (!timestamp || signatures.length === 0) return false;
  const age = Math.abs(Date.now() / 1000 - Number(timestamp));
  if (!Number.isFinite(age) || age > 300) return false;
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign(
    "HMAC",
    cryptoKey,
    new TextEncoder().encode(`${timestamp}.${body}`),
  );
  const hex = [...new Uint8Array(mac)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
  return signatures.some((value) => value === hex);
}
