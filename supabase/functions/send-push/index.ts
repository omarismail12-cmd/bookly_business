import { sendFcm } from "../_shared/fcm.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST")
    return new Response("Method Not Allowed", { status: 405 });
  const workerSecret = Deno.env.get("NOTIFICATION_WORKER_SECRET");
  if (workerSecret && req.headers.get("x-notification-secret") !== workerSecret)
    return new Response("Unauthorized", { status: 401 });
  try {
    const body = await req.json();
    if (!body.token || !body.title || !body.body)
      return new Response("Invalid payload", { status: 400 });
    await sendFcm(body.token, body.title, body.body, body.data ?? {});
    return new Response(JSON.stringify({ sent: true }), {
      headers: { "content-type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ sent: false, error: String(e) }), {
      status: 500,
      headers: { "content-type": "application/json" },
    });
  }
});
