---
title: qiniu
---

The qiniu target publishes your package artifacts to the [qiniu.com](https://qiniu.com).

## 设置环境变量

需要设置一些环境变量才能正确运行。

```
export QINIU_ACCESS_KEY="your access key"
export QINIU_SECRET_KEY="your secret key"
```

## 用法

运行：

```
flutter_distributor publish \
  --path dist/1.0.0+1/hello_world-1.0.0+1-android.apk \
  --targets qiniu \
  --qiniu-bucket your-bucket \
  --qiniu-bucket-domain https://dl.example.com \
  --qiniu-savekey-prefix myall/
```

### 配置 `distribute_options.yaml`

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

运行：

```
flutter_distributor release --name dev
```

## 更新发布日志

`args` 中加上 `update-version-info: true`（默认 `false`）后，包上传成功会调用后台
`update_version_info` 接口写入发布日志：

- `version` 取自当前项目的 `pubspec.yaml`
- `apk_url` 为上传成功后的下载地址（因此开启时必须配置 `bucket-domain`）
- `remark` 取自环境变量 `PGYER_UPDATE_DESCRIPTION_DETAIL`
- `publish_date` 为发布当天本地零点（与后台列表的按天存储/筛选一致）
- `id`、`update_policy`、`has_bug`、`operator` 为固定值

```yaml
        publish:
          target: qiniu
          args:
            bucket: your bucket
            bucket-domain: https://dl.example.com
            update-version-info: true
```

接口调用失败（HTTP 非 200 或返回体 `result != true`）时包已上传成功，但会抛出错误提示发布日志未更新。
