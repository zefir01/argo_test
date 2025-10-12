local argo = import '../libs/argo.libsonnet';
local k8s = import '../libs/k8s.libsonnet';

{
  local _keycloak = function(name, db_obj, logLevel='error', wave=null) {
    apiVersion: 'k8s.keycloak.org/v2alpha1',
    kind: 'Keycloak',
    metadata: {
      name: name,
      namespace: 'keycloak-operator',
      [if wave != null then 'annotations']: {
        'argocd.argoproj.io/sync-wave': std.toString(wave),
      },
    },
    spec: {
      instances: 1,
      image: argo.revisions.keycloak.master,
      db: {
        vendor: 'mysql',
        host: argo.config.rds.master.db_host,
        database: 'keycloak',
        port: 3306,
        usernameSecret: {
          name: 'mysql',
          key: 'mysql_db_user',
        },
        passwordSecret: {
          name: 'mysql',
          key: 'mysql_db_pass',
        },
        //url: 'jdbc:' + db_obj.db_url,
      },
      hostname: {
        strict: true,
        hostname: argo.config.env.keycloak.domain,
        adminUrl: 'https://' + argo.config.env.keycloak.domain + '/',
      },
      ingress: {
        enabled: false,
      },
      http: {
        httpEnabled: true,
      },
      features: {
        disabled: [
          'step-up-authentication',
        ],
      },
      transaction: {
        xaEnabled: false,
      },
      additionalOptions: [
        {
          name: 'log-level',
          value: logLevel,
        },
      ],
    },
  },
  keycloak:: _keycloak,

  local _client = function(name, labels, roles, wave=null) {
    apiVersion: 'legacy.k8s.keycloak.org/v1alpha1',
    kind: 'KeycloakClient',
    metadata: {
      name: name,
      namespace: 'keycloak-operator',
      labels: labels,
      [if wave != null then 'annotations']: {
        'argocd.argoproj.io/sync-wave': std.toString(wave),
      },
    },
    spec: {
      realmSelector: {
        matchLabels: labels,
      },
      roles: [
        {
          name: r,
        }
        for r in roles
      ],
      client: {
        clientId: name,
        secret: name,
        clientAuthenticatorType: name,
        protocol: 'openid-connect',
      },
    },
  },
  client:: _client,

  local _user = function(name, labels, wave=null) {
    apiVersion: 'legacy.k8s.keycloak.org/v1alpha1',
    kind: 'KeycloakUser',
    metadata: {
      name: name,
      namespace: 'keycloak-operator',
      labels: labels,
      [if wave != null then 'annotations']: {
        'argocd.argoproj.io/sync-wave': std.toString(wave),
      },
    },
    spec: {
      realmSelector: {
        matchLabels: labels,
      },
      user: {
        username: name,
        firstName: name,
        lastName: name,
        email: 'creds_user@redhat.com',
        enabled: true,
        emailVerified: false,
        /*
        credentials: [
          {
            type: 'password',
            value: '12345',
          },
        ],
        */
        realmRoles: [
          'offline_access',
        ],
        clientRoles: {
          account: [
            'manage-account',
          ],
          'realm-management': [
            'manage-users',
          ],
        },
      },
    },
  },
  user:: _user,
}
