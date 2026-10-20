---
title: qiniu
---

The qiniu target publishes your package artifacts to the [qiniu.com](https://qiniu.com).

## Set up environment variables

requires some environment variables set up to run correctly.

```
export QINIU_ACCESS_KEY="your access key"
export QINIU_SECRET_KEY="your secret key"
```

## Usage

Run:

```
flutter_distributor publish \
  --path dist/1.0.0+1/hello_world-1.0.0+1-android.apk \
  --targets qiniu \
  --qiniu-bucket your-bucket \
  --qiniu-bucket-domain https://dl.example.com \
  --qiniu-savekey-prefix myall/
```

### Configure `distribute_options.yaml`

```yaml
variables:
  QINIU_ACCESS_KEY: your access key
  QINIU_SECRET_KEY: your secret key
output: dist/
releases:
  - name: dev
    jobs:
      - name: release-dev-android
        package:
          platform: android
          target: apk
        # Publish to qiniu
        publish:
          target: qiniu
          args:
            bucket: your bucket
            bucket-domain: https://dl.example.com
            savekey-prefix: myapp/
```

Run:

```
flutter_distributor release --name dev
```

## Update release notes

Add `update-version-info: true` (default `false`) to `args`. After a successful
upload the publisher calls the backend `update_version_info` API with:

- `version` from the current project's `pubspec.yaml`
- `apk_url` of the uploaded artifact (so `bucket-domain` is required when enabled)
- `remark` from the `PGYER_UPDATE_DESCRIPTION_DETAIL` environment variable
- `publish_date` as local midnight of the release day, matching how the backend
  stores and filters it
- fixed `id`, `update_policy`, `has_bug` and `operator` values

```yaml
        publish:
          target: qiniu
          args:
            bucket: your bucket
            bucket-domain: https://dl.example.com
            update-version-info: true
```

If the call fails (non-200 or a body whose `result` is not `true`) the package
is already uploaded, but the publish still throws so the missing release note
is visible.
