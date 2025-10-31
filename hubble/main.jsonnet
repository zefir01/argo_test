local argo = import '../libs/argo.libsonnet';
local c = import '../libs/cilium.libsonnet';
local k8s = import '../libs/k8s.libsonnet';
local o = import '../libs/oauth-proxy.libsonnet';
local es = import '../libs/external_secrets.libsonnet';

[
  es.externalSecret('github', 'hubble-github'),

  o.github_pod(
    'oauth',
    argo.config.env.hubble_access,
    'hubble',
    argo.config.domain,
    'http://hubble-ui.kube-system.svc.cluster.local:80',
    'github',
    replicas=1
  ),

  k8s.service(
    'oauth',
    { app: 'oauth' },
    [k8s.service_port('http', 80, 'http')],
    wave=20
  ),

  c.httpRoute('echoserver', ['hubble.'+argo.config.domain], [
    c.rulePrefix('/', 'oauth'),
  ]),
]
