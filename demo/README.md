# Demo

The demo application is simply Wordpress deployed to an existing Kubernetes
cluster. The installation process is intentionally convoluted to show how tools
can be chained together using Porter and CNAB.

The installation process is as follows:
1. Terraform is used to create a namespace that is specified as a parameter.
1. Helm is used to install Wordpress into this namespace.

## Running the demo

### Prerequisites

* Windows or macOS
  * [Docker Desktop](https://www.docker.com/get-started)
* Linux
  * [Docker Engine](https://www.docker.com/get-started)
  * Access to a Kubernetes cluster
* [Porter](https://porter.sh/install/)

If using Docker Desktop, ensure that you
[turn on Kubernetes](https://docs.docker.com/docker-for-windows/#kubernetes)
before starting.

### Demo steps

### Inspect the bundle

You can get information about the bundle using the `porter bundle explain`
command:

```console
$ porter bundle explain
Description: KubeCon EU 2020 CNAB demo
Version: 0.1.0

Credentials:
Name         Description                                                                Required
kubeconfig   Kubernetes config to use for creation of namespace and deployment of app   true

Parameters:
Name        Description                                            Type     Default          Required   Applies To
context     Context in the Kubernetes config to use                string   docker-desktop   false      All Actions
namespace   Kubernetes namespace to create and deploy app within   string   kubecon          false      All Actions

Outputs:
Name        Description                                 Type     Applies To
namespace   Kubernetes namespace created by Terraform   string   install

No custom actions defined
```

This shows what credentials are required to deploy and manage the application,
what parameters one can modify, and outputs that CNAB actions can generate.

#### Generate a credential set

In order for our application bundle to access your Kubernetes cluster, you will
need to create a credential set with a Kubernetes config file.
In the same directory that you have your `porter.yaml`, run:

```console
$ porter credentials generate kubecred
Generating new credential kubecred from bundle kubecon-eu-2020
==> 1 credentials required for bundle kubecon-eu-2020
? How would you like to set credential "kubeconfig"
   [Use arrows to move, space to select, type to filter]
  secret
  specific value
  environment variable
> file path
  shell command
```

Select `file path` and then enter the path to your Kubernetes config file:

```console
? How would you like to set credential "kubeconfig"
  file path
? Enter the path that will be used to set credential "kubeconfig"
$HOME/.kube/config
```

You can verify that you have created a `kubecred` credential set as follows:

```console
$ porter credentials list
NAME       MODIFIED
kubecred   33 seconds ago
```

#### Install the bundle

To install the application to your Kubernetes cluster, you will use the
`porter install` command. You will also need to pass which credential set to use
and optionally the parameters you would like to change.

```console
$ porter install myapp --cred kubecred --param="context=docker-desktop" --param="namespace=kubecon"
```

Porter can show you which CNABs you have installed:

```console
$ porter list
NAME    CREATED         MODIFIED        LAST ACTION   LAST STATUS
myapp   9 seconds ago   2 seconds ago   install       succeeded
```

You can check that the `kubecon` namespace was created on your Kubernetes
cluster:

```console
$ kubectl get namespaces
NAME              STATUS   AGE
default           Active   6h51m
kube-node-lease   Active   6h51m
kube-public       Active   6h51m
kube-system       Active   6h51m
kubecon           Active   10s
```

You should also see the Wordpress components starting to come up in the
`kubecon` namespace:

```console
$ kubectl get all --namespace kubecon
NAME                                             READY   STATUS    RESTARTS   AGE
pod/kubecon-eu-2020-mariadb-0                    0/1     Running   0          24s
pod/kubecon-eu-2020-wordpress-5b9d8fb7b6-v96pz   0/1     Running   0          24s

NAME                                TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
service/kubecon-eu-2020-mariadb     ClusterIP      10.107.133.232   <none>        3306/TCP                     25s
service/kubecon-eu-2020-wordpress   LoadBalancer   10.107.10.89     localhost     80:30070/TCP,443:31260/TCP   25s

NAME                                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/kubecon-eu-2020-wordpress   0/1     1            0           25s

NAME                                                   DESIRED   CURRENT   READY   AGE
replicaset.apps/kubecon-eu-2020-wordpress-5b9d8fb7b6   1         1         0       25s

NAME                                       READY   AGE
statefulset.apps/kubecon-eu-2020-mariadb   0/1     25s
```

Once all the components are running, and if you are using Docker Desktop, you
will be able to navigate to Wordpress at `http://localhost:80`. If using a
remote Kubernetes, you will find the application at your LoadBalancer address.

#### Uninstall the bundle

To uninstall the application, you will need to give the bundle access to your
Kubernetes credentials:

```console
$ porter uninstall myapp --cred kubecred
```

Once this has been run, the `kubecon` namespace should no longer exist:

```console
$ kubectl get namespaces
NAME              STATUS   AGE
default           Active   7h
kube-node-lease   Active   7h
kube-public       Active   7h
kube-system       Active   7h
```

#### Publish the bundle to a container registry

To share the CNAB, you can push it to a container registry like
[Docker Hub](https://hub.docker.com). This is done using the `porter publish`
command. Note that you will need to replace `ccrone` with your own Docker Hub
user handle:

```console
$ porter publish --tag ccrone/kubecon-eu-2020:v0.1.0
```

**Note:** If you see the error when pushing, it may be because you have exceeded
the number of private Docker Hub repositories that you are allowed. Navigate to
the Hub and make the `kubecon-eu-2020` and `kubecon-eu-2020-installer`
repositories public and then republish your CNAB.

Others can then install use your CNAB package directly from the Docker Hub:

```console
$ porter install myregistryapp --cred kubecred --tag ccrone/kubecon-eu-2020:v0.1.0
```

You can check as you did that the application has been installed, this time
named `myregistryapp`:

```console
$ porter list
NAME            CREATED          MODIFIED         LAST ACTION   LAST STATUS
myregistryapp   39 seconds ago   33 seconds ago   install       succeeded
```

Finally you can remove the application as you did before:

```console
$ porter uninstall myregistryapp --cred kubecred
```

#### Store the bundle for offline use

CNAB bundles can also be stored offline for use in air gapped situations.
Porter provides the `porter bundle archive` command to generate a tarball of the
application package.

```console
$ mkdir -p archive
$ porter bundle archive --tag ccrone/kubecon-eu-2020:v0.1.0 archive/kubecon-eu-2020.tgz
```

You can extract the tarball to see the CNAB inside:

```console
$ cd archive/
$ tar xzf kubecon-eu-2020.tgz
$ ls
artifacts           bundle.json         kubecon-eu-2020.tgz
```

Inside the artifacts directory is an
[OCI image layout](https://github.com/opencontainers/image-spec/blob/v1.0.1/image-layout.md)
of the registry representation of the invocation image from the CNAB.
Note that Porter exports a "thin" bundle which excludes the component container
images that make up Wordpress in this instance.

Porter abstracts the complexity of the CNAB specification implementation from
the user. You can see the
[CNAB bundle file](https://github.com/cnabio/cnab-spec/blob/cnab-core-1.0.1/101-bundle-json.md),
the `bundle.json`, here though:

```console
$ cat bundle.json | jq .
```
```json
{
  "credentials": {
    "kubeconfig": {
      "path": "/root/.kube/config",
      "required": true
    }
  },
  "custom": {
    "sh.porter": {
      "manifest": "IyBJbnN0YWxsaW5nIHRoaXMgYXBwbGljYXRpb24gd2lsbCB5aWVsZCBhIHNpbXBsZSBXb3JkcHJlc3MgYmxvZyBvbiBhbiBleGlzdGluZwojIEt1YmVybmV0ZXMgY2x1c3Rlci4KIyBUaGUgcHJvY2VzcyBvZiBpbnN0YWxsaW5nIGludm9sdmVzOgojIC0gQ3JlYXRpbmcgYSBuZXcgbmFtZXNwYWNlIHVzaW5nIFRlcnJhZm9ybQojIC0gRGVwbG95aW5nIFdvcmRwcmVzcyBpbnRvIHRoaXMgbmFtZXNwYWNlIHVzaW5nIEhlbG0KCiMgQXBwbGljYXRpb24gbWV0YWRhdGEuCm5hbWU6IGt1YmVjb24tZXUtMjAyMAp2ZXJzaW9uOiAwLjEuMApkZXNjcmlwdGlvbjogIkt1YmVDb24gRVUgMjAyMCBDTkFCIGRlbW8iCnRhZzogY2Nyb25lL2t1YmVjb24tZXUtMjAyMDp2MC4xLjAKCiMgQmFzZSBEb2NrZXJmaWxlIHVzZWQgYXMgYSB0ZW1wbGF0ZSBmb3IgdGhlIENOQUIgaW5zdGFsbGVyLgpkb2NrZXJmaWxlOiBEb2NrZXJmaWxlLnRtcGwKCiMgVGhlIHRvb2xzIHRoYXQgYXJlIHJlcXVpcmVkIHRvIGRlcGxveSB0aGlzIGFwcGxpY2F0aW9uLgojIEEgbGlzdCBvZiBtaXhpbnMgY2FuIGJlIGZvdW5kIGhlcmU6IGh0dHBzOi8vcG9ydGVyLnNoL21peGlucy8KbWl4aW5zOgogIC0gdGVycmFmb3JtOgogICAgICBjbGllbnRWZXJzaW9uOiAwLjEzLjAtcmMxCiAgLSBoZWxtCgojIENyZWRlbnRpYWxzIGFyZSBzZW5zaXRpdmUgaW5mb3JtYXRpb24gcmVxdWlyZWQgdG8gZGVwbG95IHRoZSBhcHBsaWNhdGlvbi4KIyBUaGVyZSBpcyBvbmUgc2V0IG9mIGNyZWRlbnRpYWxzIGxpc3RlZCBoZXJlIGFzIHJlcXVpcmVkIGZvciB0aGUgYXBwbGljYXRpb246CiMgLSBBIEt1YmVybmV0ZXMgY29uZmlnIGZpbGUgdGhhdCBpcyBtb3VudGVkIHRvIGAvcm9vdC8ua3ViZS9jb25maWdgIGluIHRoZQojICAgQ05BQiBpbnN0YWxsZXIuCmNyZWRlbnRpYWxzOgogIC0gbmFtZToga3ViZWNvbmZpZwogICAgcGF0aDogL3Jvb3QvLmt1YmUvY29uZmlnCgojIFBhcmFtZXRlcnMgYXJlIHVzZXIgc2V0dGluZ3MgdGhhdCBhcmUgdXNlZCB0byBjb25maWd1cmUgdGhlIGFwcGxpY2F0aW9uLgojIFRoZXJlIGFyZSB0d28gcGFyYW1ldGVycyBsaXN0ZWQgaGVyZToKIyAtIFRoZSBLdWJlcm5ldGVzIGNvbnRleHQgdG8gdXNlIChkZWZhdWx0OiBkb2NrZXItZGVza3RvcCkKIyAtIFRoZSBLdWJlcm5ldGVzIG5hbWVzcGFjZSB0byBjcmVhdGUgYW5kIHVzZSBmb3IgdGhpcyBhcHBsaWNhdGlvbgojICAgKGRlZmF1bHQ6IGt1YmVjb24pCnBhcmFtZXRlcnM6CiAgLSBuYW1lOiBjb250ZXh0CiAgICB0eXBlOiBzdHJpbmcKICAgIGRlZmF1bHQ6ICJkb2NrZXItZGVza3RvcCIKICAtIG5hbWU6IG5hbWVzcGFjZQogICAgdHlwZTogc3RyaW5nCiAgICBkZWZhdWx0OiAia3ViZWNvbiIKCiMgT3V0cHV0cyBhcmUgY29sbGVjdGVkIGZyb20gYSBzdGFnZSBpbiBhIENOQUIgYWN0aW9uLiBUaGlzIGFsbG93cyBjYXB0dXJpbmcKIyBpbmZvcm1hdGlvbiBmcm9tIG9uZSBzdGFnZSAoZS5nLjogYSBVUkwpIGFuZCB1c2luZyBpdCBpbiBhbm90aGVyLgojIEluIHRoaXMgY2FzZSB3ZSBoYXZlIGEgc2luZ2xlIG91dHB1dDoKIyAtIG5hbWVzcGFjZSB0aGF0IGlzIGZpbGxlZCBieSB0aGUgVGVycmFmb3JtIGluc3RhbGwgc3RlcC4Kb3V0cHV0czoKICAtIG5hbWU6IG5hbWVzcGFjZQogICAgdHlwZTogc3RyaW5nCiAgICBhcHBseVRvOgogICAgICAtIGluc3RhbGwgIyBXZSB3aWxsIG9ubHkgZmlsbCB0aGlzIG91dHB1dCBpbiB0aGUgaW5zdGFsbCBhY3Rpb24uCgojIFRoZSBpbnN0YWxsIGFjdGlvbiBkZWZpbmVzIHRoZSBzdGVwcyByZXF1aXJlZCB0byBpbnN0YWxsIHRoZSBhcHBsaWNhdGlvbi4KIyBJbiB0aGlzIGNhc2UsIHdlIHN0YXJ0IGJ5IGNyZWF0aW5nIGEgS3ViZXJuZXRlcyBuYW1lc3BhY2UgdXNpbmcgVGVycmFmb3JtLgojIFRoZSBuYW1lIG9mIHRoZSBuYW1lc3BhY2UgaXMgYSBwYXJhbWV0ZXIgd2l0aCBhIGRlZmF1bHQgdmFsdWUgb2YgImt1YmVjb24iLgojIE9uY2UgdGhlIG5hbWVzcGFjZSBoYXMgYmVlbiBjcmVhdGVkLCBIZWxtIGlzIHVzZWQgdG8gaW5zdGFsbCBXb3JkcHJlc3MgaW50bwojIHRoZSBuYW1lc3BhY2UuIE5vdGUgdGhhdCB0aGUgVGVycmFmb3JtIHN0ZXAgb3V0cHV0cyB0aGUgbmFtZXNwYWNlIG5hbWUgYW5kCiMgdGhhdCB0aGlzIGlzIHVzZWQgYnkgdGhlIEhlbG0gc3RlcC4KaW5zdGFsbDoKICAtIHRlcnJhZm9ybToKICAgICAgZGVzY3JpcHRpb246ICJDcmVhdGUgYXBwbGljYXRpb24gS3ViZXJuZXRlcyBuYW1lc3BhY2UiCiAgICAgIGJhY2tlbmRDb25maWc6CiAgICAgICAgIyBDb25maWd1cmUgdGhlIFRlcnJhZm9ybSBiYWNrZW5kIHRvIHVzZSBhIEt1YmVybmV0ZXMgc2VjcmV0IGZvciBzdGF0ZQogICAgICAgICMgd2l0aCB0aGUgYnVuZGxlIG5hbWUgYXMgaXRzIHByZWZpeC4KICAgICAgICBzZWNyZXRfc3VmZml4OiAie3sgYnVuZGxlLm5hbWUgfX0iCiAgICAgIHZhcnM6CiAgICAgICAgY29udGV4dDogInt7IGJ1bmRsZS5wYXJhbWV0ZXJzLmNvbnRleHQgfX0iCiAgICAgICAgbmFtZXNwYWNlOiAie3sgYnVuZGxlLnBhcmFtZXRlcnMubmFtZXNwYWNlIH19IgogICAgICBvdXRwdXRzOgogICAgICAgIC0gbmFtZTogbmFtZXNwYWNlCiAgLSBoZWxtOgogICAgICBkZXNjcmlwdGlvbjogIkluc3RhbGwgV29yZHByZXNzIgogICAgICBuYW1lOiAie3sgYnVuZGxlLm5hbWUgfX0iCiAgICAgICMgU2VlOiBodHRwczovL2dpdGh1Yi5jb20vZGVpc2xhYnMvcG9ydGVyLXRlcnJhZm9ybS9pc3N1ZXMvMjAKICAgICAgIyBuYW1lc3BhY2U6ICJ7eyBidW5kbGUub3V0cHV0cy5uYW1lc3BhY2UgfX0iCiAgICAgIG5hbWVzcGFjZTogInt7IGJ1bmRsZS5wYXJhbWV0ZXJzLm5hbWVzcGFjZSB9fSIKICAgICAgY2hhcnQ6IHN0YWJsZS93b3JkcHJlc3MKICAgICAgcmVwbGFjZTogdHJ1ZQoKIyBUaGUgdXBncmFkZSBhY3Rpb24gc2ltcGx5IHVzZXMgSGVsbSB0byB1cGdyYWRlIFdvcmRwcmVzcyB0byB0aGUgbGF0ZXN0IHN0YWJsZQojIHZlcnNpb24uCnVwZ3JhZGU6CiAgLSBoZWxtOgogICAgICBkZXNjcmlwdGlvbjogIlVwZ3JhZGUgV29yZHByZXNzIgogICAgICBuYW1lOiAie3sgYnVuZGxlLm5hbWUgfX0iCiAgICAgICMgU2VlOiBodHRwczovL2dpdGh1Yi5jb20vZGVpc2xhYnMvcG9ydGVyLXRlcnJhZm9ybS9pc3N1ZXMvMjAKICAgICAgIyBuYW1lc3BhY2U6ICJ7eyBidW5kbGUub3V0cHV0cy5uYW1lc3BhY2UgfX0iCiAgICAgIG5hbWVzcGFjZTogInt7IGJ1bmRsZS5wYXJhbWV0ZXJzLm5hbWVzcGFjZSB9fSIKICAgICAgY2hhcnQ6IHN0YWJsZS93b3JkcHJlc3MKCiMgVGhlIHVuaW5zdGFsbCBhY3Rpb24gc3RhcnRzIGJ5IHVzaW5nIEhlbG0gdG8gcmVtb3ZlIFdvcmRwcmVzcyBhbmQgdGhlbiB1c2VzCiMgVGVycmFmb3JtIHRvIHJlbW92ZSB0aGUgbmFtZXNwYWNlIHdlIGNyZWF0ZWQuCnVuaW5zdGFsbDoKICAtIGhlbG06CiAgICAgIGRlc2NyaXB0aW9uOiAiVW5pbnN0YWxsIFdvcmRwcmVzcyIKICAgICAgcHVyZ2U6IHRydWUKICAgICAgcmVsZWFzZXM6CiAgICAgICAgLSAie3sgYnVuZGxlLm5hbWUgfX0iCiAgLSB0ZXJyYWZvcm06CiAgICAgIGRlc2NyaXB0aW9uOiAiUmVtb3ZlIGFwcGxpY2F0aW9uIEt1YmVybmV0ZXMgbmFtZXNwYWNlIgogICAgICBiYWNrZW5kQ29uZmlnOgogICAgICAgICMgQ29uZmlndXJlIHRoZSBUZXJyYWZvcm0gYmFja2VuZCB0byB1c2UgYSBLdWJlcm5ldGVzIHNlY3JldCBmb3Igc3RhdGUKICAgICAgICAjIHdpdGggdGhlIGJ1bmRsZSBuYW1lIGFzIGl0cyBwcmVmaXguCiAgICAgICAgc2VjcmV0X3N1ZmZpeDogInt7IGJ1bmRsZS5uYW1lIH19IgogICAgICB2YXJzOgogICAgICAgIGNvbnRleHQ6ICJ7eyBidW5kbGUucGFyYW1ldGVycy5jb250ZXh0IH19IgogICAgICAgICMgU2VlOiBodHRwczovL2dpdGh1Yi5jb20vZGVpc2xhYnMvcG9ydGVyLXRlcnJhZm9ybS9pc3N1ZXMvMjAKICAgICAgICAjIG5hbWVzcGFjZTogInt7IGJ1bmRsZS5vdXRwdXRzLm5hbWVzcGFjZSB9fSIKICAgICAgICBuYW1lc3BhY2U6ICJ7eyBidW5kbGUucGFyYW1ldGVycy5uYW1lc3BhY2UgfX0iCg==",
      "manifestDigest": "f3e97f54aad2ef9316f0dc81449c823cc0ced9fe6325cf62628f7162127f5c51",
      "mixins": {
        "helm": {},
        "terraform": {}
      }
    }
  },
  "definitions": {
    "context-parameter": {
      "default": "docker-desktop",
      "type": "string"
    },
    "namespace-output": {
      "type": "string"
    },
    "namespace-parameter": {
      "default": "kubecon",
      "type": "string"
    },
    "porter-debug-parameter": {
      "default": false,
      "description": "Print debug information from Porter when executing the bundle",
      "type": "boolean"
    }
  },
  "description": "KubeCon EU 2020 CNAB demo",
  "invocationImages": [
    {
      "contentDigest": "sha256:b8a758db17ab4a14508a1ca2b10cf7b5b8a2b345a28c097c00a40a13c384222f",
      "image": "ccrone/kubecon-eu-2020-installer:v0.1.0",
      "imageType": "docker",
      "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
      "size": 2637
    }
  ],
  "name": "kubecon-eu-2020",
  "outputs": {
    "namespace": {
      "applyTo": [
        "install"
      ],
      "definition": "namespace-output",
      "path": "/cnab/app/outputs/namespace"
    }
  },
  "parameters": {
    "context": {
      "definition": "context-parameter",
      "destination": {
        "env": "CONTEXT"
      }
    },
    "namespace": {
      "definition": "namespace-parameter",
      "destination": {
        "env": "NAMESPACE"
      }
    },
    "porter-debug": {
      "definition": "porter-debug-parameter",
      "description": "Print debug information from Porter when executing the bundle",
      "destination": {
        "env": "PORTER_DEBUG"
      }
    }
  },
  "schemaVersion": "v1.0.0",
  "version": "0.1.0"
}
```

## Files

### porter.yaml

The [`porter.yaml`](./porter.yaml) is a manifest where one can define what tools
and steps are required for installing, upgrading, and uninstalling the
application. Detailed documentation about this can be found
[here](https://porter.sh/author-bundles/).

Each section of the demo [`porter.yaml`](./porter.yaml) has comments explaining
them.

### terraform/

Comments can be found inside the Terraform files:

- [terraform/main.tf](./terraform/main.tf)
- [terraform/outputs.tf](./terraform/outputs.tf)
- [terraform/variables.tf](./terraform/variables.tf)
