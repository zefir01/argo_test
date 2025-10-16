local argo = import './argo.libsonnet';

{

  stepWeight(weight):: {
    setWeight: weight,
  },
  stepAnalysis(templates):: {
    analysis: {
      templates: [if std.isString(t) then { templateName: t } else t for t in templates],
      args: [
        {
          name: 'stable-hash',
          valueFrom: {
            podTemplateHashValue: 'Stable',
          },
        },
        {
          name: 'latest-hash',
          valueFrom: {
            podTemplateHashValue: 'Latest',
          },
        },
      ],
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
          name: 'latest-hash',
        },
      ],
      metrics: [
        {
          name: 'success-rate',
          interval: '1m',
          successCondition: 'len(result) == 0 or result[0] == 0',
          failureLimit: 3,
          count: 15,
          provider: {
            prometheus: {
              address: argo.config.amp_url,
              query: 'kube_pod_container_status_restarts_total{rollouts_pod_template_hash="{{args.latest-hash}}"}',
              authentication: {
                sigv4: {
                  region: argo.config.region,
                },
              },
            },
          },
        },
      ],
    },
  },
}
