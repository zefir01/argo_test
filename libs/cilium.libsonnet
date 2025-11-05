local argo = import '../libs/argo.libsonnet';
local cm = import '../libs/cert-manager.libsonnet';
local k8s = import '../libs/k8s.libsonnet';

{
  gatewayClass(name='cilium', wave=null):: {
    apiVersion: 'gateway.networking.k8s.io/v1',
    kind: 'GatewayClass',
    metadata: {
      name: name,
      [if wave != null then 'annotations']: {
        'argocd.argoproj.io/sync-wave': std.toString(wave),
      },
    },
    spec: {
      controllerName: 'io.cilium/gateway-controller',
    },
  },

  gateway(name, issuer, namespace=null, gatewayClass='cilium', wave=null):: {
    apiVersion: 'gateway.networking.k8s.io/v1',
    kind: 'Gateway',
    metadata: {
      name: name,
      [if namespace != null then 'namespace']: namespace,
      annotations: {
        'cert-manager.io/cluster-issuer': issuer,
        'kubernetes.io/tls-acme': 'true',
        [if wave != null then 'argocd.argoproj.io/sync-wave']: std.toString(wave),
      },
    },
    spec: {
      gatewayClassName: gatewayClass,
      infrastructure: {
        annotations: {
          'service.beta.kubernetes.io/aws-load-balancer-type': 'nlb',
          'service.beta.kubernetes.io/aws-load-balancer-nlb-target-type': 'instance',
          'service.beta.kubernetes.io/aws-load-balancer-scheme': 'internet-facing',
          'service.beta.kubernetes.io/aws-load-balancer-proxy-protocol': '*',
          'service.beta.kubernetes.io/aws-load-balancer-alpn-policy': 'HTTP2Preferred',
        },
      },
      listeners: [
        {
          name: 'http',
          hostname: '*.' + argo.config.domain,
          protocol: 'HTTP',
          port: 80,
          allowedRoutes: {
            namespaces: {
              from: 'All',
            },
          },
        },
        {
          name: 'https',
          hostname: '*.' + argo.config.domain,
          protocol: 'HTTPS',
          port: 443,
          allowedRoutes: {
            namespaces: {
              from: 'All',
            },
          },
          tls: {
            mode: 'Terminate',
            certificateRefs: [
              {
                group: '',
                kind: 'Secret',
                name: name + '-tls',
              },
            ],
          },
        },
      ],
    },
  },

  rulePrefix(prefix, service, port=80, backendRefs=[
    {
      group: '',
      kind: 'Service',
      name: service,
      port: port,
      weight: 1,
    },
  ]):: {
    matches: [
      {
        path: {
          type: 'PathPrefix',
          value: prefix,
        },
      },
    ],
    backendRefs: backendRefs,
  },

  httpRoute(name, domains, rules, gateway='main', namespace=null, wave=null, rollouts=false):: {
    apiVersion: 'gateway.networking.k8s.io/v1',
    kind: 'HTTPRoute',
    metadata: {
      name: name,
      [if namespace != null then 'namespace']: namespace,
      [if wave != null || rollouts then 'annotations']: {
        'argocd.argoproj.io/sync-wave': std.toString(wave),
        [if rollouts then 'rollouts']: 'true',
      },
    },
    spec: {
      parentRefs: [
        {
          group: 'gateway.networking.k8s.io',
          kind: 'Gateway',
          name: gateway,
          namespace: 'argo',
          sectionName: 'http',
        },
        {
          group: 'gateway.networking.k8s.io',
          kind: 'Gateway',
          name: gateway,
          namespace: 'argo',
          sectionName: 'https',
        },
      ],
      hostnames: domains,
      rules: rules,
    },
  },

  policy_http_log(name, labels, ports=[80], namespace=null, wave=null,):: {
    apiVersion: 'cilium.io/v2',
    kind: 'CiliumNetworkPolicy',
    metadata: {
      name: name,
      [if namespace != null then 'namespace']: namespace,
      [if wave != null then 'annotations']: {
        'argocd.argoproj.io/sync-wave': std.toString(wave),
      },
    },
    spec: {
      endpointSelector: {},
      ingress: [
        {
          fromEntities: ['all'],
          toPorts: [
            {
              ports: [
                {
                  port: std.toString(port),
                  protocol: 'TCP',
                }
                for port in ports
              ],
              rules: {
                http: [
                  {},
                ],
              },
            },
          ],
        },
      ],
      egress: [
        {
          toPorts: [
            {
              ports: [
                {
                  port: std.toString(port),
                  protocol: 'TCP',
                }
                for port in ports
              ],
              rules: {
                http: [
                  {},
                ],
              },
            },
          ],
        },
        { toEntities: ['all'] },
      ],
    },
  },

}
