export interface OAuthState {
  verifier: string;
  redirectUri?: string;
  createdAt: number;
}

export interface OAuthTokenResponse {
  access_token?: string;
  token_type?: string;
  scope?: string;
  error?: string;
  error_description?: string;
}
