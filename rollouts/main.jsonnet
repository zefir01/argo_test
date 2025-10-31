local argo = import '../libs/argo.libsonnet';
local c = import '../libs/cilium.libsonnet';
local k8s = import '../libs/k8s.libsonnet';
local o = import '../libs/oauth-proxy.libsonnet';
local es = import '../libs/external_secrets.libsonnet';

[
  es.externalSecret('github', 'rollouts-github'),

  argo.app_helm(
    'argo-rollouts',
    'argo-rollouts',
    'https://argoproj.github.io/argo-helm',
    'argo-rollouts',
    '2.40.5',
    valuesObject={
      serviceAccount: {
        annotations: {
          'eks.amazonaws.com/role-arn': argo.config.argo_rollouts_irsa,
        },
      },
      dashboard: {
        enabled: true,
      },
      controller: {
        trafficRouterPlugins: [
          {
            name: 'argoproj-labs/gatewayAPI',
            location: 'https://github.com/argoproj-labs/rollouts-plugin-trafficrouter-gatewayapi/releases/download/v0.4.0/gatewayapi-plugin-linux-amd64',
          },
        ],
      },
    },
    wave=10
  ),

  o.github_pod(
    'oauth',
    argo.config.env.hubble_access,
    'hubble',
    argo.config.domain,
    'http://argo-rollouts-dashboard.argo-rollouts.svc.cluster.local:3100',
    'github',
    replicas=1
  ),

  k8s.service(
    'oauth',
    { app: 'oauth' },
    [k8s.service_port('http', 80, 'http')],
    wave=20
  ),

  c.httpRoute('rollouts', ['rollouts.'+argo.config.domain], [
    c.rulePrefix('/', 'oauth'),
  ], wave=30),
]
