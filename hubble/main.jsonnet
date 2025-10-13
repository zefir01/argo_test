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

  o.github_pod(
    'oauth',
    'zefir01',
    'hubble',
    'pstukalov-test.com',
    'http://hubble-ui.kube-system.svc.cluster.local:80',
    'oauth-proxy',
    replicas=1
  ),

  k8s.service(
    'oauth',
    { app: 'oauth' },
    [k8s.service_port('http', 80, 'http')],
    wave=20
  ),

  c.httpRoute('echoserver', ['hubble.pstukalov-test.com'], [
    c.rulePrefix('/', 'oauth'),
  ]),
]
