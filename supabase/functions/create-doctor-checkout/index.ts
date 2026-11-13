import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }

  const json = (status: number, body: Record<string, unknown>) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...cors, "Content-Type": "application/json" },
    });

  const key = Deno.env.get("STRIPE_SECRET_KEY");
  const price = Deno.env.get("STRIPE_PRICE_ID");
  if (!key || !price) {
    return json(503, {
      error: "O pagamento no site ainda não está configurado.",
    });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    {
      global: {
        headers: { Authorization: req.headers.get("Authorization") ?? "" },
      },
    },
  );
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return json(401, { error: "Entre na conta para assinar." });

  const { data: profile } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .maybeSingle();
  if (profile?.role !== "doctor") {
    return json(403, {
      error: "O plano do consultório é só para a conta de médico.",
    });
  }

  const params = new URLSearchParams({
    mode: "subscription",
    "line_items[0][price]": price,
    "line_items[0][quantity]": "1",
    success_url: "https://examefacil.pages.dev/#/plano?pago=1",
    cancel_url: "https://examefacil.pages.dev/#/plano",
    client_reference_id: user.id,
    "metadata[user_id]": user.id,
    "subscription_data[metadata][user_id]": user.id,
  });
  if (user.email) params.set("customer_email", user.email);

  const stripe = await fetch("https://api.stripe.com/v1/checkout/sessions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: params,
  });
  const session = await stripe.json();
  if (!stripe.ok || typeof session.url !== "string") {
    return json(502, { error: "Não foi possível abrir o pagamento." });
  }
  return json(200, { url: session.url });
});
