local argo = import '../libs/argo.libsonnet';
local c = import '../libs/cilium.libsonnet';
local istio = import '../libs/istio.libsonnet';
local k8s = import '../libs/k8s.libsonnet';

[
  k8s.deployment(
    'echoserver', [
      k8s.deployment_container(
        'ealen/echo-server:latest',
        'echoserver',
        [k8s.deployment_container_port('http', 80, 'TCP')],
        k8s.deployment_container_http_probe('http'),
        resources=k8s.deployment_container_resources('500m', '4Gi', '1', '8Gi'),
      ),
    ],
    wave=20,
    replicas=5
  ),

  k8s.service(
    'echoserver',
    { app: 'echoserver' },
    [k8s.service_port('http', 80, 'http')],
    wave=20
  ),

  c.httpRoute('echoserver', ['echo.oncentrl-test.com'], [
    c.rulePrefix('/', 'echoserver'),
  ]),
]
