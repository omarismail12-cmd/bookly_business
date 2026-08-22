import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async () => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { data: jobs, error } = await supabase
    .from("notification_jobs")
    .select(
      "*,customers:recipient_customer_id(name,email),appointments(starts_at)",
    )
    .eq("status", "pending")
    .lte("scheduled_for", new Date().toISOString())
    .order("scheduled_for")
    .limit(100);
  // notification_jobs.title/body (set by send_campaign()) override the
  // kind-based copy below; every other job kind still falls back to it.
  if (error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
    });
  let sent = 0,
    failed = 0;
  for (const job of jobs ?? []) {
    const customerId = job.recipient_customer_id;
    const userId = job.recipient_user_id;
    let tokenQuery = supabase.from("device_tokens").select("token").limit(20);
    if (customerId) tokenQuery = tokenQuery.eq("customer_id", customerId);
    else if (userId) tokenQuery = tokenQuery.eq("user_id", userId);
    else {
      await supabase
        .from("notification_jobs")
        .update({ status: "failed", error: "No recipient" })
        .eq("id", job.id);
      failed++;
      continue;
    }
    const { data: tokens } = await tokenQuery;
    const title =
      job.title ??
      (job.kind === "confirmation"
        ? "Booking confirmed"
        : job.kind === "reminder_24h"
          ? "Appointment tomorrow"
          : job.kind === "reminder_2h"
            ? "Appointment reminder"
            : "Bookly Business");
    const body =
      job.body ??
      (job.kind === "confirmation"
        ? "Your Bookly appointment is confirmed."
        : job.kind === "reminder_24h"
          ? "You have an appointment in about 24 hours."
          : job.kind === "reminder_2h"
            ? "You have an appointment in about 2 hours."
            : "");
    let jobSent = false;
    for (const t of tokens ?? []) {
      const response = await fetch(
        `${Deno.env.get("SUPABASE_URL")}/functions/v1/send-push`,
        {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-notification-secret":
              Deno.env.get("NOTIFICATION_WORKER_SECRET") ?? "",
          },
          body: JSON.stringify({
            token: t.token,
            title,
            body,
            data: { appointment_id: job.appointment_id ?? "" },
          }),
        },
      );
      if (response.ok) jobSent = true;
    }
    if (jobSent) {
      await supabase
        .from("notification_jobs")
        .update({
          status: "sent",
          sent_at: new Date().toISOString(),
          error: null,
        })
        .eq("id", job.id);
      sent++;
    } else {
      await supabase
        .from("notification_jobs")
        .update({
          status: "failed",
          error: "No valid device token or FCM delivery failed",
        })
        .eq("id", job.id);
      failed++;
    }
  }
  return new Response(
    JSON.stringify({ processed: jobs?.length ?? 0, sent, failed }),
    { headers: { "content-type": "application/json" } },
  );
});
