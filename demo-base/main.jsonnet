local argo = import '../libs/argo.libsonnet';

[
  argo.app(
    'demo-' + name,
    'demo-' + name,
    'demo',
    wave=40,
    istio=true,
    config={
      instance_name: name,
    },
    labels={
      demo: name,
    },
  )
  for name in std.objectFields(argo.config.env.demo.instances)
]
