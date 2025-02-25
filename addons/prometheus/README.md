## [Prometheus](https://github.com/prometheus/prometheus) and [node_exporter](https://github.com/prometheus/node_exporter)
Podcheck check is capable to export metrics to prometheus via the text file collector provided by the node_exporter.
In order to do so the -c flag has to be specified followed by the file path that is configured in the text file collector of the node_exporter.
A simple cron job can be configured to export these metrics on a regular interval as shown in the sample below:

```
0 1 * * * /root/podcheck.sh -n -c /var/lib/node_exporter/textfile_collector
```

The following metrics are exported to prometheus

```
# HELP podcheck_images_analyzed Podman images that have been analyzed
# TYPE podcheck_images_analyzed gauge
podcheck_images_analyzed 22
# HELP podcheck_images_outdated Podman images that are outdated
# TYPE podcheck_images_outdated gauge
podcheck_images_outdated 7
# HELP podcheck_images_latest Podman images that are outdated
# TYPE podcheck_images_latest gauge
podcheck_images_latest 14
# HELP podcheck_images_error Podman images with analysis errors
# TYPE podcheck_images_error gauge
podcheck_images_error 1
# HELP podcheck_images_analyze_timestamp_seconds Last podcheck run time
# TYPE podcheck_images_analyze_timestamp_seconds gauge
podcheck_images_analyze_timestamp_seconds 1737924029
```

Once those metrics are exported they can be used to define alarms as shown below

```
- alert: podcheck_images_outdated
  expr: sum by(instance) (podcheck_images_outdated) > 0
  for: 15s
  labels:
    severity: warning
  annotations:
    summary: "{{ $labels.instance }} has {{ $value }} outdated podman images."
    description: "{{ $labels.instance }} has {{ $value }} outdated podman images."
- alert: podcheck_images_error
  expr: sum by(instance) (podcheck_images_error) > 0
  for: 15s
  labels:
    severity: warning
  annotations:
    summary: "{{ $labels.instance }} has {{ $value }} podman images having an error."
    description: "{{ $labels.instance }} has {{ $value }} podman images having an error."
- alert: podcheck_image_last_analyze
  expr: (time() - podcheck_images_analyze_timestamp_seconds) > (3600 * 24 * 3)
  for: 15s
  labels:
    severity: warning
  annotations:
    summary: "{{ $labels.instance }} has not updated the podcheck statistics for more than  3 days."
    description: "{{ $labels.instance }} has not updated the podcheck statistics for more than 3 days."
```

There is a reference Grafana dashboard in [grafana/grafana_dashboard.json](./grafana/grafana_dashboard.json).

![](./grafana/grafana_dashboard.png)
