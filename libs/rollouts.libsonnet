local argo = import './argo.libsonnet';

{

  stepWeight(weight):: {
    setWeight: weight,
  },
  stepAnalysis(templates):: {
    [if std.length(templates)>0 then 'analysis']: {
      templates: [if std.isString(t) then { templateName: t } else t for t in templates],
    },
  },
  stepPause(duration=null):: {
    pause: if duration == null then {} else { duration: duration },
  },

  canary(name, containers, canaryService, stableService, httpRoute, steps, httpRouteNamespace=argo.config.app_name, replicas=1, labels={ app: name }, wave=null):: {
    apiVersion: 'argoproj.io/v1alpha1',
    kind: 'Rollout',
    metadata: {
      name: name,
      [if wave != null then 'annotations']: {
        'argocd.argoproj.io/sync-wave': std.toString(wave),
      },
    },
    spec: {
      replicas: replicas,
      revisionHistoryLimit: 10,
      selector: {
        matchLabels: labels,
      },
      template: {
        metadata: {
          labels: labels,
        },
        spec: {
          containers: containers,
        },
      },
      strategy: {
        canary: {
          canaryService: canaryService,
          stableService: stableService,
          trafficRouting: {
            plugins: {
              'argoproj-labs/gatewayAPI': {
                httpRoute: httpRoute,
                namespace: httpRouteNamespace,
              },
            },
          },
          steps: steps,
        },
      },
    },
    labels:: labels,
  },

  analisysTemplate():: {
    apiVersion: 'argoproj.io/v1alpha1',
    kind: 'AnalysisTemplate',
    metadata: {
      name: 'success-rate',
    },
    spec: {
      args: [
        {
          name: 'service-name',
        },
      ],
      metrics: [
        {
          name: 'success-rate',
          interval: '5m',
          successCondition: 'result[0] >= 0.95',
          failureLimit: 3,
          provider: {
            prometheus: {
              address: argo.config.amp_url,
              query: 'sum(irate(\n  istio_requests_total{reporter="source",destination_service=~"{{args.service-name}}",response_code!~"5.*"}[5m]\n)) /\nsum(irate(\n  istio_requests_total{reporter="source",destination_service=~"{{args.service-name}}"}[5m]\n))\n',
              authentication: {
                sigv4: {
                  region: '$REGION',
                  profile: '$PROFILE',
                  roleArn: '$ROLEARN',
                },
              },
            },
          },
        },
      ],
    },
  },
}
