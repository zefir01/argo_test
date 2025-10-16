local argo = import '../libs/argo.libsonnet';
local c = import '../libs/cilium.libsonnet';
local k8s = import '../libs/k8s.libsonnet';
local r = import '../libs/rollouts.libsonnet';


local obj = {
  stableService: k8s.service(
    'test-stable',
    { app: 'test' },
    [k8s.service_port('http', 80, 'http')],
  ),
  canaryService: k8s.service(
    'test-canary',
    { app: 'test' },
    [k8s.service_port('http', 80, 'http')],
  ),
  httpRoute: c.httpRoute('test', ['test.pstukalov-test.com'], [
    c.rulePrefix('/', '', backendRefs=[
      {
        group: '',
        kind: 'Service',
        name: obj.stableService.metadata.name,
        port: 80,
        weight: 1
      },
      {
        group: '',
        kind: 'Service',
        name: obj.canaryService.metadata.name,
        port: 80,
        weight: 1
      },
    ]),
  ], wave=20, rollouts=true),

  rollout: r.canary(
    'test',
    [
      k8s.deployment_container(
        'argoproj/rollouts-demo:green',
        'demo',
        [k8s.deployment_container_port('http', 8080, 'TCP')],
        k8s.deployment_container_http_probe('http'),
        //resources=k8s.deployment_container_resources('500m', '4Gi', '1', '8Gi'),
      ),
    ],
    canaryService=obj.canaryService.metadata.name,
    stableService=obj.stableService.metadata.name,
    httpRoute=obj.httpRoute.metadata.name,
    labels=obj.stableService.spec.selector,
    replicas=2,
    wave=30
  ),
};

[obj[name] for name in std.objectFields(obj)]
