declare const Deno: {
  env: {
    get(name: string): string | undefined;
  };
};

function base64Url(input: Uint8Array): string {
  let binary = "";

  for (const b of input) {
    binary += String.fromCharCode(b);
  }

  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function textBase64Url(input: string): string {
  return base64Url(new TextEncoder().encode(input));
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const clean = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");

  const binary = atob(clean);
  const bytes = new Uint8Array(binary.length);

  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }

  return bytes.buffer;
}

export async function fcmAccessToken(
  projectId: string,
  clientEmail: string,
  privateKey: string,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  const header = textBase64Url(
    JSON.stringify({
      alg: "RS256",
      typ: "JWT",
    }),
  );

  const payload = textBase64Url(
    JSON.stringify({
      iss: clientEmail,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    }),
  );

  const unsigned = `${header}.${payload}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(privateKey),
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );

  const assertion = `${unsigned}.${base64Url(new Uint8Array(signature))}`;

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "content-type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });

  const body = await response.json();

  if (!response.ok || !body.access_token) {
    throw new Error(
      `FCM auth failed: ${
        body.error_description ?? body.error ?? "unknown error"
      }`,
    );
  }

  return body.access_token;
}

export async function sendFcm(
  token: string,
  title: string,
  body: string,
  data: Record<string, string> = {},
): Promise<void> {
  const projectId = Deno.env.get("FCM_PROJECT_ID");
  const clientEmail = Deno.env.get("FCM_CLIENT_EMAIL");

  const privateKey = Deno.env.get("FCM_PRIVATE_KEY")?.replace(/\\n/g, "\n");

  if (!projectId || !clientEmail || !privateKey) {
    throw new Error("FCM secrets are not configured");
  }

  const accessToken = await fcmAccessToken(projectId, clientEmail, privateKey);

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${accessToken}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: {
            title,
            body,
          },
          data,
        },
      }),
    },
  );

  if (!response.ok) {
    throw new Error(`FCM send failed: ${await response.text()}`);
  }
}
