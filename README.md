# 腾讯手机管家 v3.0

## 自动构建 (GitHub Actions)
1. Fork/上传此目录到 GitHub 仓库
2. Actions → Build IPA → Run workflow
3. 下载 artifact → 得到 IPA

## 手动构建 (Mac + Xcode)
```bash
chmod +x build.sh
./build.sh
```

## 项目结构
```
Sources/          Swift 源码
Shaders/          Metal 着色器
Info.plist        应用配置
Entitlements.plist 权限配置  
build.sh          构建脚本
```

## 构建完成后
IPA 在项目根目录, 用 TrollStore Force Install 安装
