local argo = import '../libs/argo.libsonnet';
local c = import '../libs/cilium.libsonnet';
local k8s = import '../libs/k8s.libsonnet';
local o = import '../libs/oauth-proxy.libsonnet';

[
  k8s.secret('oauth-proxy', stringData={
    client_id: 'Ov23liw8vzFtx8ek4aiI',
    client_secret: 'cd0875f9840ef8cc53ef9e9269924e7cdb6c3ce2',
    cookie_secret: 'AhgeePhee7sheeQu',
  }),

  argo.app_helm(
    'argo-rollouts',
    'argo-rollouts',
    'https://argoproj.github.io/argo-helm',
    'argo-rollouts',
    '2.40.5',
    valuesObject={
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

  //  k8s.configMap('argo-rollouts-config', {
  //    trafficRouterPlugins: std.manifestYamlDoc(
  //      [
  //        {
  //          name: 'argoproj-labs/gatewayAPI',
  //          location: 'https://github.com/argoproj-labs/rollouts-plugin-trafficrouter-gatewayapi/releases/download/v0.4.0/gatewayapi-plugin-linux-amd64',
  //        },
  //      ],
  //      indent_array_in_object=false,
  //      quote_keys=false
  //    ),
  //  }, namespace='argo-rollouts', wave=11),

  o.github_pod(
    'oauth',
    'zefir01',
    'hubble',
    'pstukalov-test.com',
    'http://argo-rollouts-dashboard.argo-rollouts.svc.cluster.local:3100',
    'oauth-proxy',
    replicas=1
  ),

  k8s.service(
    'oauth',
    { app: 'oauth' },
    [k8s.service_port('http', 80, 'http')],
    wave=20
  ),

  c.httpRoute('rollouts', ['rollouts.pstukalov-test.com'], [
    c.rulePrefix('/', 'oauth'),
  ], wave=30),
]
