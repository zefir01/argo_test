local argo = import '../libs/argo.libsonnet';
local c = import '../libs/cilium.libsonnet';
local k8s = import '../libs/k8s.libsonnet';
local o = import '../libs/oauth-proxy.libsonnet';

[
  k8s.secret('oauth-proxy', stringData={
    client_id: 'Ov23lipmITFNbDOrFjuv',
    client_secret: 'b1a76cf753c4a9cddb53650ad7d8297f01534c4d',
    cookie_secret: 'AhgeePhee7sheeQu',
  }),

  o.github_pod(
    'oauth',
    'peter.stukalov01@gmail.com',
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
