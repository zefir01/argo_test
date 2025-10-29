local argo = import '../libs/argo.libsonnet';
local istio = import '../libs/istio.libsonnet';
local k8s = import '../libs/k8s.libsonnet';
local s = import '../libs/secrets.libsonnet';
local c = import '../libs/cilium.libsonnet';

local instance = argo.config.env.demo.instances[argo.config.instance_name];
local image = argo.revisions['demo-app'][instance.revision];

[
  k8s.deployment(
    'demo', [
      k8s.deployment_container(
        image,
        'demo',
        [k8s.deployment_container_port('http', 80, 'TCP')],
        k8s.deployment_container_http_probe('http'),
        env=[
          k8s.var('TEST_PARAM', instance.test_param)
        ],
      ),
    ],
    wave=20,
    replicas=instance.replicas
  ),

  k8s.service(
    'demo',
    { app: 'demo' },
    [k8s.service_port('http', 80, 'http')],
    wave=20
  ),

  c.httpRoute('demo', ['demo.'+argo.config.domain], [
    c.rulePrefix('/', 'demo'),
  ]),
]
