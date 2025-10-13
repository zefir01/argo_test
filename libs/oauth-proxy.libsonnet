local k8s = import 'k8s.libsonnet';

{
  sidecar:: function(
    client_secret_name,
    app_port,
    keycloak_endpoint,
    realm_name,
    app_endpoint
           ) k8s.deployment_container(
    'quay.io/oauth2-proxy/oauth2-proxy:v7.6.0',
    'oauth-proxy',
    [
      k8s.deployment_container_port('oauth', 8809, 'TCP'),
    ],
    liveness_probe=k8s.deployment_container_http_probe('oauth', '/ping'),
    readiness_probe=k8s.deployment_container_http_probe('oauth', '/ping'),
    env=[
      k8s.secretVar('OAUTH2_PROXY_CLIENT_ID', client_secret_name, 'client_name'),
      k8s.secretVar('OAUTH2_PROXY_CLIENT_SECRET', client_secret_name, 'client_secret'),
      k8s.secretVar('OAUTH2_PROXY_COOKIE_SECRET', client_secret_name, 'cookie_secret'),

      k8s.var('OAUTH2_PROXY_PROVIDER', 'oidc'),
      k8s.var('OAUTH2_PROXY_EMAIL_DOMAINS', '*'),
      k8s.var('OAUTH2_PROXY_SCOPE', 'openid'),
      k8s.var('OAUTH2_PROXY_UPSTREAMS', 'http://127.0.0.1:' + std.toString(app_port)),
      k8s.var('OAUTH2_PROXY_HTTP_ADDRESS', '0.0.0.0:8809'),
      k8s.var('OAUTH2_PROXY_PROXY_PREFIX', '/oauth2'),
      k8s.var('OAUTH2_PROXY_LOGIN_URL', 'https://' + keycloak_endpoint + '/realms/' + realm_name + '/protocol/openid-connect/auth'),
      k8s.var('OAUTH2_PROXY_REDEEM_URL', 'https://' + keycloak_endpoint + '/realms/' + realm_name + '/protocol/openid-connect/token'),
      k8s.var('OAUTH2_PROXY_VALIDATE_URL', 'https://' + keycloak_endpoint + '/realms/' + realm_name + '/protocol/openid-connect/userinfo'),
      k8s.var('OAUTH2_PROXY_REDIRECT_URL', 'https://' + app_endpoint + '/oauth2/callback'),
      k8s.var('OAUTH2_PROXY_SKIP_AUTH_PREFLIGHT', 'true'),
      k8s.var('OAUTH2_PROXY_SKIP_JWT_BEARER_TOKENS', 'true'),
      //k8s.var('OAUTH2_PROXY_SKIP_AUTH_ROUTES', 'GET: /schema.json'),
      k8s.var('OAUTH2_PROXY_COOKIE_HTTPONLY', 'true'),
      k8s.var('OAUTH2_PROXY_COOKIE_SECURE', 'false'),
      k8s.var('OAUTH2_PROXY_COOKIE_SAMESITE', 'lax'),
      k8s.var('OAUTH2_PROXY_COOKIE_DOMAINS', app_endpoint),
      k8s.var('OAUTH2_PROXY_COOKIE_REFRESH', '1m'),
      k8s.var('OAUTH2_PROXY_STANDARD_LOGGING', 'true'),
      k8s.var('OAUTH2_PROXY_AUTH_LOGGING', 'true'),
      k8s.var('OAUTH2_PROXY_REQUEST_LOGGING', 'false'),
      k8s.var('OAUTH2_PROXY_PASS_ACCESS_TOKEN', 'true'),
      k8s.var('OAUTH2_PROXY_PASS_AUTHORIZATION_HEADER', 'true'),
      k8s.var('OAUTH2_PROXY_OIDC_ISSUER_URL', 'https://' + keycloak_endpoint + '/realms/' + realm_name),
      k8s.var('OAUTH2_PROXY_OIDC_JWKS_URL', 'https://' + keycloak_endpoint + '/realms/' + realm_name + '/protocol/openid-connect/certs'),
      k8s.var('OAUTH2_PROXY_SKIP_OIDC_DISCOVERY', 'false'),  //true
      k8s.var('OAUTH2_PROXY_INSECURE_OIDC_ALLOW_UNVERIFIED_EMAIL', 'false'),
      k8s.var('OAUTH2_PROXY_SKIP_PROVIDER_BUTTON', 'true'),
      k8s.var('OAUTH2_PROXY_SET_AUTHORIZATION_HEADER', 'true'),
    ]
  ),

  github_pod(name, email, subdomain, domain, upstream, secret, replicas=1, namespace=null)::
    k8s.deployment(
      name,
      [
        k8s.deployment_container(
          'quay.io/oauth2-proxy/oauth2-proxy:v7.6.0',
          'oauth2-proxy',
          [k8s.deployment_container_port('http', 4180, 'TCP')],
          k8s.deployment_container_http_probe('http', path='/ping'),
          k8s.deployment_container_http_probe('http', path='/ping'),
          args=[
            '--provider=github',
            '--http-address=0.0.0.0:4180',
            '--upstream=' + upstream,
            '--redirect-url=https://' + subdomain + '.' + domain + '/oauth2/callback',
            '--email-domain=*',
            '--github-user=' + email,
            '--cookie-secure=true',
            '--cookie-samesite=lax',
            '--cookie-domain=.' + domain,
            '--pass-access-token=true',
            '--set-xauthrequest=true',
            '--skip-provider-button=true',
          ],
          env=[
            k8s.secretVar('OAUTH2_PROXY_CLIENT_ID', secret, 'client_id'),
            k8s.secretVar('OAUTH2_PROXY_CLIENT_SECRET', secret, 'client_secret'),
            k8s.secretVar('OAUTH2_PROXY_COOKIE_SECRET', secret, 'cookie_secret'),
          ],
          resources=k8s.deployment_container_resources('10m', '128Mi', '300m', '256Mi'),
        ),
      ],
      replicas=replicas
    ),
}
