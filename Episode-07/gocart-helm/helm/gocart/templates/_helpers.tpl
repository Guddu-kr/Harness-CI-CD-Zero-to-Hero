{{/*
============================================
_helpers.tpl — Reusable template snippets
These are like "functions" you can call from any template file.
Usage in other files: {{ include "gocart.fullname" . }}
============================================
*/}}

{{/*
Full name: combines release name + chart name
Example: if you run "helm install myrelease ./gocart"
         this returns "myrelease-gocart"
*/}}
{{- define "gocart.fullname" -}}
{{- .Release.Name }}-{{ .Chart.Name }}
{{- end }}

{{/*
Standard labels — added to every resource for tracking
.Release.Name    = name given during helm install
.Chart.Name      = "gocart" (from Chart.yaml)
.Chart.Version   = "1.0.0" (from Chart.yaml)
.Chart.AppVersion = "1.0.0" (from Chart.yaml)
.Release.Service = "Helm"
*/}}
{{- define "gocart.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels — used by Deployment to find its Pods
Must match between Deployment.spec.selector and Pod.metadata.labels
*/}}
{{- define "gocart.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
