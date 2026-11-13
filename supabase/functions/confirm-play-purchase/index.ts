import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// A compra só libera o consultório depois que o servidor confere o recibo
// na Google Play Developer API. Sem essa credencial, a resposta é 503 e o
// plano permanece inativo.
Deno.serve((req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }
  return Response.json(
    { error: "A confirmação da compra na Play ainda não está configurada." },
    { status: 503, headers: cors },
  );
});
