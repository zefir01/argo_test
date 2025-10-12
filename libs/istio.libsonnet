local cm = import '../libs/cert-manager.libsonnet';
local k8s = import '../libs/k8s.libsonnet';

{
  local _ingress = function(domains, healthcheckPort, tls=true, waf_arn=null, wave=null) k8s.alb_ingress(
    'gw-ingress',
    'gw-ingress',
    domains,
    [
      k8s.alb_ingress_rule(d,
                           [k8s.alb_ingress_rule_path('/', 'istio-gateway', if tls then 443 else 80)],
                           filter_x_forwarded_for=false)
      for d in domains
    ],
    is_internal=false,
    external_dns=true,
    namespace='istio-ingress',
    backendHttps=true,
    annotations={
      'alb.ingress.kubernetes.io/healthcheck-protocol': 'HTTP',  //--HTTPS by default
      'alb.ingress.kubernetes.io/healthcheck-port': healthcheckPort,  //--traffic-port by default
      'alb.ingress.kubernetes.io/healthcheck-path': '/healthz/ready',  //--/ by default
      'alb.ingress.kubernetes.io/actions.filter-x-forwarded-for': std.toString(
        {
          type: 'fixed-response',
          fixedResponseConfig: {
            contentType: 'text/plain',
            statusCode: '400',
            messageBody: 'x-forwarded-for not allowed',
          },
        }
      ),
      'alb.ingress.kubernetes.io/conditions.filter-x-forwarded-for': std.toString(
        [
          {
            field: 'http-header',
            httpHeaderConfig: {
              httpHeaderName: 'x-forwarded-for',
              values: ['*'],
            },
          },
        ]
      ),
    },
    waf_arn=waf_arn,
    wave=wave
  ),
  ingress:: _ingress,

  local _gws = function(name, hosts, namespace, wave=null) [
    {
      apiVersion: 'networking.istio.io/v1alpha3',
      kind: 'Gateway',
      metadata: {
        name: name,
        namespace: namespace,
        [if wave != null then 'annotations']: {
          'argocd.argoproj.io/sync-wave': std.toString(wave),
        },
      },
      spec: {
        selector: {
          istio: 'gateway',
        },
        servers: [
          {
            port: {
              number: 443,
              name: 'https',
              protocol: 'HTTPS',
            },
            tls: {
              mode: 'SIMPLE',
              credentialName: namespace + '-ingress-' + name + '-tls',
            },
            hosts: ['*'],
            //hosts: ['test-payload/*'],
          },
        ],
      },
    },

    cm.cert(namespace + '-ingress-' + name + '-tls',
            namespace + '-ingress-' + name + '-tls',
            hosts[0],
            dnsNames=hosts,
            namespace='istio-ingress',
            wave=wave),
  ],
  gws:: _gws,

  local _virtualServiceRule = function(prefixes, host, port, match_headers=null, request_headers=null, response_headers={}, rewritePrefix=false, cors=null, hsts=true) {
    match: [
      {
        uri: {
          prefix: prefix,
        },
        [if match_headers != null then 'headers']: match_headers,
      }
      for prefix in prefixes
    ],
    [if rewritePrefix then 'rewrite']: {
      uri: '/',
    },
    [if request_headers != null then 'headers']: {
      request: {
        set: request_headers,
      },
    },
    route: [
      {
        destination: {
          host: host,
          port: {
            number: port,
          },
        },
        [if hsts || response_headers != {} then 'headers']: {
          response: {
            set: {
              [if hsts then 'Strict-Transport-Security']: 'max-age=31536000; includeSubDomains',
            } + response_headers,
          },
        },
      },
    ],
    [if cors != null then 'corsPolicy']: cors,
  },
  virtualServiceRule:: _virtualServiceRule,

  local _virtualServiceRuleDirectResponse = function(uri, body=null, headers=null, status=200, cors=null) {
    match: [
      {
        uri: {
          exact: uri,
        },
      },
    ],
    directResponse: {
      status: status,
      [if body != null then 'body']: {
        string: std.toString(body),
      },
    },
    [if headers != null then 'headers']: {
      response: {
        set: headers,
      },
    },
    [if cors != null then 'corsPolicy']: cors,
  },
  virtualServiceRuleDirectResponse:: _virtualServiceRuleDirectResponse,

  local _virtualService = function(name, rules, hosts, namespace=null, wave=null, gateways=['istio-system/main', 'istio-system/http']) {
    apiVersion: 'networking.istio.io/v1alpha3',
    kind: 'VirtualService',
    metadata: {
      name: name,
      [if namespace != null then 'namespace']: namespace,
      [if wave != null then 'annotations']: {
        'argocd.argoproj.io/sync-wave': std.toString(wave),
      },
    },
    spec: {
      hosts: hosts,
      gateways: gateways,
      http: rules,
    },
  },
  virtualService:: _virtualService,

  local _corsPolicy = function(domain) {
    allowOrigins: [
      {
        exact: domain,
      },
    ],
    allowMethods: [
      'GET',
      'POST',
      'PUT',
      'PATCH',
      'DELETE',
      'OPTIONS',
    ],
    allowCredentials: true,
    allowHeaders: [
      '*',
    ],
    maxAge: '24h',
  },
  corsPolicy:: _corsPolicy,

  local _gw = function(name, hosts, namespace, wave=null) {
    apiVersion: 'networking.istio.io/v1alpha3',
    kind: 'Gateway',
    metadata: {
      name: name,
      namespace: namespace,
      [if wave != null then 'annotations']: {
        'argocd.argoproj.io/sync-wave': std.toString(wave),
      },
    },
    spec: {
      selector: {
        istio: 'gateway',
      },
      servers: [
        {
          port: {
            number: 80,
            name: 'http',
            protocol: 'HTTP',
          },
          hosts: hosts,
        },
      ],
    },
  },
  gw:: _gw,

  local _telemetry = function(namespace=null, wave=null) {
    apiVersion: 'telemetry.istio.io/v1alpha1',
    kind: 'Telemetry',
    metadata: {
      name: 'stdout',
      [if namespace != null then 'namespace']: namespace,
      [if wave != null then 'annotations']: {
        'argocd.argoproj.io/sync-wave': std.toString(wave),
      },
    },
    spec: {
      accessLogging: [
        {
          providers: [
            {
              name: 'envoy',
            },
          ],
        },
      ],
    },
  },
  telemetry:: _telemetry,

  local _authPolicyIpFilter = function(name, ips, selector=null, namespace=null, wave=null) {
    apiVersion: 'security.istio.io/v1beta1',
    kind: 'AuthorizationPolicy',
    metadata: {
      name: name,
      [if namespace != null then 'namespace']: namespace,
      [if wave != null then 'annotations']: {
        'argocd.argoproj.io/sync-wave': std.toString(wave),
      },
    },
    spec: {
      [if selector != null then 'selector']: {
        matchLabels: selector,
      },
      action: 'ALLOW',
      rules: [
        {
          from: [
            {
              source: {
                remoteIpBlocks: ips,
              },
            },
          ],
        },
      ],
    },
  },
  authPolicyIpFilter:: _authPolicyIpFilter,


  local _authPolicyGetFilter = function(name, paths, selector=null, namespace=null, wave=null) {
    apiVersion: 'security.istio.io/v1beta1',
    kind: 'AuthorizationPolicy',
    metadata: {
      name: name,
      [if namespace != null then 'namespace']: namespace,
      [if wave != null then 'annotations']: {
        'argocd.argoproj.io/sync-wave': std.toString(wave),
      },
    },
    spec: {
      [if selector != null then 'selector']: {
        matchLabels: selector,
      },
      action: 'ALLOW',
      rules: [
        {
          to: [
            {
              operation: {
                methods: ['GET'],
                paths: paths,
              },
            },
          ],
        },
      ],
    },
  },
  authPolicyGetFilter:: _authPolicyGetFilter,

  local _authPolicyRuleIp = function(ips) {
    from: [
      {
        source: {
          remoteIpBlocks: ips,
        },
      },
    ],
  },
  authPolicyRuleIp:: _authPolicyRuleIp,

  authPolicyRuleNotIp(ips):: {
    from: [
      {
        source: {
          notRemoteIpBlocks: ips,
        },
      },
    ],
  },

  local _authPolicyRuleNamespaces = function(namespaces) {
    from: [
      {
        source: {
          namespaces: namespaces,
        },
      },
    ],
  },
  authPolicyRuleNamespaces:: _authPolicyRuleNamespaces,

  local _authPolicyRulePath = function(paths, methods=['GET']) {
    to: [
      {
        operation: {
          methods: methods,
          paths: paths,
        },
      },
    ],
  },
  authPolicyRulePath:: _authPolicyRulePath,

  local _authPolicy = function(name, rules, selector=null, allow=true, namespace=null, wave=null) {
    apiVersion: 'security.istio.io/v1beta1',
    kind: 'AuthorizationPolicy',
    metadata: {
      name: name,
      [if namespace != null then 'namespace']: namespace,
      [if wave != null then 'annotations']: {
        'argocd.argoproj.io/sync-wave': std.toString(wave),
      },
    },
    spec: {
      [if selector != null then 'selector']: {
        matchLabels: selector,
      },
      action: if allow then 'ALLOW' else 'DENY',
      rules: rules,
    },
  },
  authPolicy:: _authPolicy,


  local _remoteIpFixFilter = function(namespace) {
    apiVersion: 'networking.istio.io/v1alpha3',
    kind: 'EnvoyFilter',
    metadata: {
      name: 'xff-envoyfilter-alb',
      namespace: namespace,
    },
    spec: {
      configPatches: [
        {
          applyTo: 'NETWORK_FILTER',
          match: {
            context: 'SIDECAR_INBOUND',
            listener: {
              filterChain: {
                filter: {
                  name: 'envoy.filters.network.http_connection_manager',
                },
              },
            },
          },
          patch: {
            operation: 'MERGE',
            value: {
              typed_config: {
                '@type': 'type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager',
                xff_num_trusted_hops: 1,
              },
            },
          },
        },
      ],
    },
  },
  remoteIpFixFilter:: _remoteIpFixFilter,

  local _xffReplacer = function(namespace) {
    apiVersion: 'networking.istio.io/v1alpha3',
    kind: 'EnvoyFilter',
    metadata: {
      name: 'xff-replacer',
      namespace: namespace,
    },
    spec: {
      configPatches: [
        {
          applyTo: 'HTTP_FILTER',
          match: {
            context: 'SIDECAR_INBOUND',
            listener: {
              filterChain: {
                filter: {
                  name: 'envoy.filters.network.http_connection_manager',
                  subFilter: {
                    name: 'envoy.filters.http.router',
                  },
                },
              },
            },
          },
          patch: {
            operation: 'INSERT_BEFORE',
            value: {
              name: 'envoy.lua',
              typed_config: {
                '@type': 'type.googleapis.com/envoy.extensions.filters.http.lua.v3.Lua',
                inlineCode: |||
                  function envoy_on_request(request_handle)
                    if request_handle:headers():get("x-envoy-external-address") then
                      request_handle:headers():replace("x-forwarded-for", request_handle:headers():get("x-envoy-external-address"))
                    end
                  end
                |||,
              },
            },
          },
        },
      ],
    },
  },
  xffReplacer:: _xffReplacer,

  local _rateLimit = function(name, selector, rpm, namespace=null) {
    apiVersion: 'networking.istio.io/v1alpha3',
    kind: 'EnvoyFilter',
    metadata: {
      name: name + '-rate-limit',
      [if namespace != null then 'namespace']: namespace,
    },
    spec: {
      workloadSelector: {
        labels: selector,
      },
      configPatches: [
        {
          applyTo: 'HTTP_FILTER',
          match: {
            context: 'SIDECAR_INBOUND',
            listener: {
              filterChain: {
                filter: {
                  name: 'envoy.filters.network.http_connection_manager',
                },
              },
            },
          },
          patch: {
            operation: 'INSERT_BEFORE',
            value: {
              name: 'envoy.filters.http.local_ratelimit',
              typed_config: {
                '@type': 'type.googleapis.com/udpa.type.v1.TypedStruct',
                type_url: 'type.googleapis.com/envoy.extensions.filters.http.local_ratelimit.v3.LocalRateLimit',
                value: {
                  stat_prefix: 'http_local_rate_limiter',
                  token_bucket: {
                    max_tokens: rpm,
                    tokens_per_fill: std.floor(rpm / 60),
                    fill_interval: '1s',
                  },
                  filter_enabled: {
                    runtime_key: 'local_rate_limit_enabled',
                    default_value: {
                      numerator: 100,
                      denominator: 'HUNDRED',
                    },
                  },
                  filter_enforced: {
                    runtime_key: 'local_rate_limit_enforced',
                    default_value: {
                      numerator: 100,
                      denominator: 'HUNDRED',
                    },
                  },
                  response_headers_to_add: [
                    {
                      append: false,
                      header: {
                        key: 'x-rate-limit',
                        value: std.toString(rpm),
                      },
                    },
                  ],
                },
              },
            },
          },
        },
      ],
    },
  },
  rateLimit:: _rateLimit,

  metrics(name, selector):: [
    {
      apiVersion: 'extensions.istio.io/v1alpha1',
      kind: 'WasmPlugin',
      metadata: {
        name: name,
      },
      spec: {
        selector: {
          matchLabels: selector,
        },
        url: 'https://storage.googleapis.com/istio-build/proxy/attributegen-359dcd3a19f109c50e97517fe6b1e2676e870c4d.wasm',
        imagePullPolicy: 'Always',
        phase: 'AUTHN',
        pluginConfig: {
          attributes: [
            {
              output_attribute: 'istio_responseClass',
              match: [
                {
                  value: '2xx',
                  condition: 'response.code >= 200 && response.code <= 299',
                },
                {
                  value: '3xx',
                  condition: 'response.code >= 300 && response.code <= 399',
                },
                {
                  value: '404',
                  condition: 'response.code == 404',
                },
                {
                  value: '429',
                  condition: 'response.code == 429',
                },
                {
                  value: '503',
                  condition: 'response.code == 503',
                },
                {
                  value: '5xx',
                  condition: 'response.code >= 500 && response.code <= 599',
                },
                {
                  value: '4xx',
                  condition: 'response.code >= 400 && response.code <= 499',
                },
              ],
            },
          ],
        },
      },
    },
    {
      apiVersion: 'telemetry.istio.io/v1alpha1',
      kind: 'Telemetry',
      metadata: {
        name: name,
      },
      spec: {
        metrics: [
          {
            overrides: [
              {
                match: {
                  metric: 'REQUEST_COUNT',
                  mode: 'CLIENT_AND_SERVER',
                },
                tagOverrides: {
                  response_code: {
                    value: 'istio_responseClass',
                  },
                },
              },
            ],
            providers: [
              {
                name: 'prometheus',
              },
            ],
          },
        ],
      },
    },
  ],

  serviceEntry(name, hosts, ports):: {
    apiVersion: 'networking.istio.io/v1beta1',
    kind: 'ServiceEntry',
    metadata: {
      name: name,
    },
    spec: {
      hosts: hosts,
      ports: [
        {
          number: p,
          name: 'port-' + p,
          protocol: 'TCP',
        }
        for p in ports
      ],
      resolution: 'DNS',
      location: 'MESH_EXTERNAL',
    },
  },
}
