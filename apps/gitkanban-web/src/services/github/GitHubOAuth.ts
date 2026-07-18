import type { OAuthState, OAuthTokenResponse } from "./GitHubOAuth.model";

export const githubClientId = import.meta.env.VITE_GITHUB_CLIENT_ID || "Iv23liCT2OlVPMuk3Mw5";

const oauthStateKey = "gitkanban-web-oauth-state";

export async function startGitHubOAuth(): Promise<void> {
  const verifier = randomString(64);
  const challenge = await codeChallenge(verifier);
  const redirectUri = configuredRedirectUri();
  const state = randomString(32);
  const stored: OAuthState = {
    verifier,
    redirectUri,
    createdAt: Date.now(),
  };
  sessionStorage.setItem(oauthStateKey, JSON.stringify({ ...stored, state }));

  const params = new URLSearchParams({
    client_id: githubClientId,
    state,
    code_challenge: challenge,
    code_challenge_method: "S256",
  });
  if (redirectUri) params.set("redirect_uri", redirectUri);

  window.location.href = `https://github.com/login/oauth/authorize?${params.toString()}`;
}

export async function consumeGitHubOAuthCallback(): Promise<string | null> {
  const url = new URL(window.location.href);
  const code = url.searchParams.get("code");
  const returnedState = url.searchParams.get("state");
  if (!code) return null;

  const raw = sessionStorage.getItem(oauthStateKey);
  if (!raw) throw new Error("Missing OAuth session. Start GitHub sign-in again.");
  const stored = JSON.parse(raw) as OAuthState & { state?: string };
  if (!stored.state || stored.state !== returnedState) {
    throw new Error("OAuth state did not match. Start GitHub sign-in again.");
  }
  if (Date.now() - stored.createdAt > 10 * 60 * 1000) {
    throw new Error("OAuth session expired. Start GitHub sign-in again.");
  }

  const params = new URLSearchParams({
    client_id: githubClientId,
    code,
    code_verifier: stored.verifier,
  });
  if (stored.redirectUri) params.set("redirect_uri", stored.redirectUri);

  const response = await fetch("https://github.com/login/oauth/access_token", {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: params,
  });
  const result = await response.json() as OAuthTokenResponse;
  if (!response.ok || result.error || !result.access_token) {
    throw new Error(result.error_description || result.error || "GitHub OAuth failed.");
  }

  sessionStorage.removeItem(oauthStateKey);
  url.searchParams.delete("code");
  url.searchParams.delete("state");
  window.history.replaceState({}, "", url.toString());
  return result.access_token;
}

function randomString(length: number): string {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~";
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (byte) => alphabet[byte % alphabet.length]).join("");
}

async function codeChallenge(verifier: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(verifier));
  return base64UrlEncode(new Uint8Array(digest));
}

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function configuredRedirectUri(): string {
  return import.meta.env.VITE_GITHUB_REDIRECT_URI || "";
}
