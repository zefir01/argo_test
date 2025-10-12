local k8s = import 'k8s.libsonnet';

{
  cluster_role:: function(name='telepresence-traffic-manager', labels=null, wave=null) k8s.cluster_role(
    name,
    [
      {
        apiGroups: [
          '',
        ],
        resources: [
          'namespaces',
        ],
        verbs: [
          'get',
          'list',
          'watch',
        ],
      },
      {
        apiGroups: [
          '',
        ],
        resources: [
          'services',
        ],
        verbs: [
          'get',
          'list',
          'watch',
        ],
      },
      {
        apiGroups: [
          '',
        ],
        resources: [
          'pods/log',
        ],
        verbs: [
          'get',
        ],
      },
      {
        apiGroups: [
          '',
        ],
        resources: [
          'pods',
        ],
        verbs: [
          'list',
          'get',
        ],
      },
      {
        apiGroups: [
          '',
        ],
        resources: [
          'services',
        ],
        verbs: [
          'list',
          'watch',
          'get',
        ],
      },
      {
        apiGroups: [
          '',
        ],
        resources: [
          'pods/portforward',
        ],
        verbs: [
          'create',
        ],
      },
      {
        apiGroups: [
          'apps',
        ],
        resources: [
          'deployments',
          'replicasets',
          'statefulsets',
        ],
        verbs: [
          'get',
          'watch',
          'list',
        ],
      },
      {
        apiGroups: [
          '',
        ],
        resourceNames: [
          'telepresence-agents',
        ],
        resources: [
          'configmaps',
        ],
        verbs: [
          'get',
          'watch',
          'list',
        ],
      },
      {
        apiGroups: [
          'getambassador.io',
        ],
        resources: [
          'ispecs',
        ],
        verbs: [
          'get',
        ],
      },
    ],
    labels=labels,
    wave=wave
  ),
}
