  (import "ksonnet-util/kausal.libsonnet") +
{
  _config:: {
    convos: {
      port: 3000,
      name: "convos",
    }
  },

  local statefulSet= $.apps.v1.statefulSet,
  local container = $.core.v1.container,
  local port = $.core.v1.containerPort,
  local service = $.core.v1.service,

  convos: {
    deployment: statefulSet.new(
      name=$._config.convos.name, replicas=1,
      containers=[
        container.new($._config.convos.name, "nordaaker/convos")
        + container.withPorts([port.new("api", $._config.convos.port)]),
      ],
      volumeClaims=[],
    ),
    service: $.util.serviceFor(self.deployment),
  },
}
