local k8s = import '../libs/k8s.libsonnet';

{
  local _rule = function(host, path, service, port) {
    host: host,
    http: {
      paths: [
        {
          path: path,
          pathType: 'Prefix',
          backend: {
            service: {
              name: service,
              port: {
                number: port,
              },
            },
          },
        },
      ],
    },
  },
  rule:: _rule,

  local _ingress = function(name, rules, plugins=null, namespace=null, wave=null) {
    apiVersion: 'networking.k8s.io/v1',
    kind: 'Ingress',
    metadata: {
      name: name,
      [if namespace != null then 'namespace']: namespace,
      annotations: {
        [if wave != null then 'argocd.argoproj.io/sync-wave']: std.toString(wave),
        //'konghq.com/strip-path': 'true',
        'cert-manager.io/cluster-issuer': 'kong',
        [if plugins != null then 'konghq.com/plugins']: std.join(',', plugins),
      },
    },
    spec: {
      ingressClassName: 'kong',
      rules: rules,
      tls: [
        {
          secretName: name,
          hosts: std.uniq([r.host for r in rules]),
        },
      ],
    },
  },
  ingress:: _ingress,

  local _alb_ingress = function(domains, service, namespace=null, waf_arn=null, wave=null) [
    k8s.alb_ingress(
      'kong-ingress',
      'kong-ingress',
      domains,
      [
        k8s.alb_ingress_rule(d,
          [k8s.alb_ingress_rule_path('/', service, 443)],
          filter_x_forwarded_for=true)
        for d in domains
      ],
      is_internal=false,
      external_dns=true,
      namespace=namespace,
      backendHttps=true,
      annotations={
        'alb.ingress.kubernetes.io/backend-protocol': 'HTTPS',
        'alb.ingress.kubernetes.io/healthcheck-protocol': 'HTTP',  //--HTTPS by default
        'alb.ingress.kubernetes.io/healthcheck-port': '31054',  //--traffic-port by default
        'alb.ingress.kubernetes.io/healthcheck-path': '/status',  //--/ by default
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
    k8s.service(
      'kong-proxy',
      {
        'app.kubernetes.io/component': 'app',
        'app.kubernetes.io/instance': 'kong',
        'app.kubernetes.io/name': 'kong',
      },
      [
        //k8s.service_port('kong-proxy', 80, 8000),
        k8s.service_port('kong-proxy-tls', 443, 8443),
        k8s.service_port('kong-status', 8100, 8100, nodePort=31054),
      ],
      type='NodePort',
      namespace=namespace,
      wave=10
    ),
  ],
  alb_ingress:: _alb_ingress,

  plugins:: {
    ip_restriction:: function(name, ips, namespace=null, wave=null) {
      apiVersion: 'configuration.konghq.com/v1',
      kind: 'KongPlugin',
      metadata: {
        name: name,
        [if namespace != null then 'namespace']: namespace,
        [if wave != null then 'annotations']: {
          'argocd.argoproj.io/sync-wave': std.toString(wave),
        },
      },
      config: {
        allow: ips,
      },
      plugin: 'ip-restriction',
    },

    request_transformer:: function(name, replace, namespace=null, wave=null) {
      apiVersion: 'configuration.konghq.com/v1',
      kind: 'KongPlugin',
      metadata: {
        name: name,
        [if namespace!=null then 'namespace']: namespace,
        [if wave != null then 'annotations']: {
          'argocd.argoproj.io/sync-wave': std.toString(wave),
        },
      },
      config: {
        replace: {
          uri: replace,
        },
      },
      plugin: 'request-transformer',
    },

    my_request_transformer:: function(name, prefixes, namespace=null, wave=null) {
      local make_function = function(prefixes) {
        local strs = [std.format('routes["%s"]= "%s"', [p.prefix, p.replace]) for p in prefixes],
        local str = std.join('\n  ', strs),
        local f = std.format(|||
          $((function()
            routes = {}
            %s
            local res=path
            for k,v in pairs(routes) do
                if str_sub(path, 1, #k) == k then
                    pat=str_gsub(k, "%%-", "%%%%-")
                    res=str_gsub(path, "^"..pat, v)
                    return res
                end
            end
            return res
          end)())
        |||, str),
        result:: f,
      },

      apiVersion: 'configuration.konghq.com/v1',
      kind: 'KongPlugin',
      metadata: {
        name: name,
        [if namespace!=null then 'namespace']: namespace,
        [if wave != null then 'annotations']: {
          'argocd.argoproj.io/sync-wave': std.toString(wave),
        },
      },
      config: {
        replace: {
          uri: make_function(prefixes).result,
        },
      },
      plugin: 'my-request-transformer',
    },

    cors:: function(name, origins, methods, headers, exposed_headers, namespace=null, wave=null) {
      apiVersion: 'configuration.konghq.com/v1',
      kind: 'KongPlugin',
      metadata: {
        name: name,
        [if namespace!=null then 'namespace']: namespace,
        [if wave != null then 'annotations']: {
          'argocd.argoproj.io/sync-wave': std.toString(wave),
        },
      },
      plugin: 'cors',
      config: {
        origins: origins,
        methods: methods,
        headers: headers,
        exposed_headers: exposed_headers,
        credentials: true,
        max_age: 3600,
      },
    },

    hsts:: function(name, namespace=null, wave=null) {
      apiVersion: 'configuration.konghq.com/v1',
      kind: 'KongPlugin',
      metadata: {
        name: name,
        [if namespace!=null then 'namespace']: namespace,
        [if wave != null then 'annotations']: {
          'argocd.argoproj.io/sync-wave': std.toString(wave),
        },
      },
      plugin: 'response-transformer',
      config: {
        add: {
          headers: [
            'Strict-Transport-Security:max-age=31536000; includeSubDomains; preload',
          ],
        },
      },
    },

    tcp_log:: function(name, host, port, namespace=null, wave=null) {
      apiVersion: 'configuration.konghq.com/v1',
      kind: 'KongPlugin',
      metadata: {
        name: name,
        [if namespace!=null then 'namespace']: namespace,
        [if wave != null then 'annotations']: {
          'argocd.argoproj.io/sync-wave': std.toString(wave),
        },
      },
      plugin: 'tcp-log',
      config: {
        host: host,
        port: port,
      },
    },

    //https://docs.konghq.com/hub/kong-inc/openid-connect/configuration/
    jwt:: function(name, issuer, namespace=null, wave=null) {
      apiVersion: 'configuration.konghq.com/v1',
      kind: 'KongPlugin',
      metadata: {
        name: name,
        [if namespace!=null then 'namespace']: namespace,
        [if wave != null then 'annotations']: {
          'argocd.argoproj.io/sync-wave': std.toString(wave),
        },
      },
      plugin: 'openid-connect',
      config: {
        auth_methods: [
          'bearer',
        ],
        issuer: issuer,
        response_mode: 'form_post',
      },
    },
  },
}
