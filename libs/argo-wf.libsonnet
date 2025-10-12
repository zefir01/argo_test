local argo = import '../libs/argo.libsonnet';
local k8s = import '../libs/k8s.libsonnet';

{
  local _articact = function(name, path, key=name, archive=true) {
    name: name,
    path: path,
    s3: {
      key: '{{workflow.namespace}}/{{workflow.name}}/' + key + if archive then '.tar.gz' else '',
    },
    [if !archive then 'archive']: {
      none: {},
    },
  },
  articact:: _articact,

  local _path = function(path) _articact { path: path },
  path:: _path,

  local _script = function(name, image, script, env=null, volumeMounts=null, resources=null, outputArtifacts=null, inputArtifacts=null, parameters=null, steps=null) {
    name: name,
    script: {
      image: image,
      command: [
        'sh',
      ],
      source: script,
      [if env != null then 'env']: env,
      [if volumeMounts != null then 'volumeMounts']: volumeMounts,
      [if resources != null then 'resources']: resources,
    },
    [if outputArtifacts != null then 'outputs']: {
      artifacts: outputArtifacts,
    },
    [if inputArtifacts != null || parameters != null then 'inputs']: {
      [if inputArtifacts != null then 'artifacts']: inputArtifacts,
      [if parameters != null then 'parameters']: parameters,
    },
    steps:: if steps == null then [{
      name: name,
      template: name,
    }] else steps,
  },
  script:: _script,

  local _container = function(name, image, command, args, env=null, resources=null, volumeMounts=null, outputArtifacts=null, inputArtifacts=null, parameters=null, steps=null) {
    name: name,
    [if outputArtifacts != null then 'outputs']: {
      artifacts: outputArtifacts,
    },
    [if inputArtifacts != null || parameters != null then 'inputs']: {
      [if inputArtifacts != null then 'artifacts']: inputArtifacts,
      [if parameters != null then 'parameters']: parameters,
    },
    steps:: if steps == null then [{
      name: name,
      template: name,
    }] else steps,
    container: {
      [if command != null then 'command']: command,
      args: args,
      [if env != null then 'env']: env,
      image: image,
      imagePullPolicy: 'IfNotPresent',
      [if resources != null then 'resources']: resources,
      [if volumeMounts != null then 'volumeMounts']: volumeMounts,
    },
  },
  container:: _container,

  local _workflowSteps = function(
    name,
    steps,
    namespace=null,
    imagePullSecrets=null,
    volumes=null,
    wave=null,
    serviceAccount='workflows',
    istioInject=false,
    annotations=null,
    generateName=false,
    onExit=[],
                        ) {
    apiVersion: 'argoproj.io/v1alpha1',
    kind: 'Workflow',
    metadata: {
      [if !generateName then 'name' else 'generateName']: name,
      [if namespace != null then 'namespace']: namespace,
      [if annotations != null || wave != null then 'annotations']: {
        [if wave != null then 'argocd.argoproj.io/sync-wave']: std.toString(wave),
      } + if annotations != null then annotations else {},
    },
    spec: {
      archiveLogs: true,
      [if onExit != [] then 'onExit']: 'exit-handler',
      ttlStrategy: {
        secondsAfterCompletion: 259200,
      },
      metrics: {
        prometheus: [
          {
            name: 'workflow_failed',
            help: 'Workflow failed counter',
            labels: [
              { key: 'workflow_namespace', value: '{{workflow.namespace}}' },
              { key: 'workflow_nname', value: name },
            ],
            when: '{{workflow.status}} != Succeeded',
            counter: {
              value: '1',
            },
          },
          {
            name: 'workflow_succeeded',
            help: 'Workflow succeeded counter',
            labels: [
              { key: 'workflow_namespace', value: '{{workflow.namespace}}' },
              { key: 'workflow_nname', value: name },
            ],
            when: '{{workflow.status}} == Succeeded',
            counter: {
              value: '1',
            },
          },
          {
            name: 'workflow_status',
            help: 'Workflow status gauge',
            labels: [
              { key: 'workflow_namespace', value: '{{workflow.namespace}}' },
              { key: 'workflow_nname', value: name },
            ],
            when: '{{workflow.status}} != Succeeded',
            gauge: {
              value: '1',
            },
          },
          {
            name: 'workflow_status',
            help: 'Workflow status gauge',
            labels: [
              { key: 'workflow_namespace', value: '{{workflow.namespace}}' },
              { key: 'workflow_nname', value: name },
            ],
            when: '{{workflow.status}} == Succeeded',
            gauge: {
              value: '0',
            },
          },
        ],
      },
      [if !istioInject then 'podMetadata']: {
        annotations: {
          'sidecar.istio.io/inject': 'false',
        },
      },
      serviceAccountName: serviceAccount,
      entrypoint: 'run',
      [if imagePullSecrets != null then 'imagePullSecrets']: [
        {
          name: imagePullSecrets,
        },
      ],
      [if volumes != null then 'volumes']: volumes,
      templates: [
        {
          name: 'run',
          steps: [
            step.steps
            for step in steps
          ],
        },
      ] + steps + if onExit == [] then [] else [
        {
          name: 'exit-handler',
          steps: [
            step.steps
            for step in onExit
          ],
        },
      ] + onExit,
    },
  },
  workflowSteps:: _workflowSteps,

  local _cron = function(name, schedule, workflowSpec, namespace=null, wave=null) {
    apiVersion: 'argoproj.io/v1alpha1',
    kind: 'CronWorkflow',
    metadata: {
      name: name,
      [if namespace != null then 'namespace']: namespace,
      [if wave != null then 'annotations']: {
        'argocd.argoproj.io/sync-wave': std.toString(wave),
      },
    },
    spec: {
      schedule: schedule,
      timezone: 'US/Eastern',
      concurrencyPolicy: 'Forbid',
      startingDeadlineSeconds: 0,
      //successfulJobsHistoryLimit: 30,
      //failedJobsHistoryLimit: 100,
      workflowSpec: workflowSpec,
    },
  },
  cron:: _cron,


  local _workflowStepsTemplate = function(name, steps, namespace=null, imagePullSecrets=null, volumes=null, wave=null, serviceAccount='workflows') {
    apiVersion: 'argoproj.io/v1alpha1',
    kind: 'WorkflowTemplate',
    metadata: {
      name: name,
      [if namespace != null then 'namespace']: namespace,
      [if wave != null then 'annotations']: {
        'argocd.argoproj.io/sync-wave': std.toString(wave),
      },
    },
    spec: {
      archiveLogs: true,
      serviceAccountName: serviceAccount,
      entrypoint: 'run',
      [if imagePullSecrets != null then 'imagePullSecrets']: [
        {
          name: imagePullSecrets,
        },
      ],
      [if volumes != null then 'volumes']: volumes,
      templates: [
        {
          name: 'run',
          steps: [
            step.steps
            for step in steps
          ],
        },
      ] + steps,
    },
  },
  workflowStepsTemplate:: _workflowStepsTemplate,

  local _artifactsStorage = function(wave=null) k8s.configMap(
    'artifact-repositories',
    {
      'default-v1-s3-artifact-repository': std.manifestYamlDoc({
        archiveLogs: true,
        s3: {
          useSDKCreds: true,
          bucket: argo.config.argo_wf_s3_id,
          keyFormat: '{{workflow.namespace}}/{{workflow.name}}',
          endpoint: 's3.amazonaws.com',
          region: argo.config.argo_wf_s3_region,
        },
      }),
    },
    annotations={
      'workflows.argoproj.io/default-artifact-repository': 'default-v1-s3-artifact-repository',
    },
    wave=wave
  ),
  artifactsStorage:: _artifactsStorage,
}
