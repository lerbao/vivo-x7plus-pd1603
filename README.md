# vivo X7Plus PD1603 无障碍滑动遥控方案

PC 端网页/命令行下发指令，手机端用 AutoJs 无障碍 `scrollForward()` 执行滑动，不依赖手势 API、不需要 root、不需要 ADB 常驻连接（ADB 仅用于一次性部署）。

实测机型：**vivo X7Plus PD1603**（Android 5.1.1 / SDK 22 / 1080×1920）

## 文件说明

| 文件 | 作用 |
|---|---|
| `phone_ctl_server.py` | PC 端 HTTP 服务：指令队列、自动上滑循环、回报日志 |
| `ctl_x7plus.bat` | X7Plus 专用控制台（端口 **8001**，日志 `phone_ack_x7plus.log`） |
| `remote_ctl_kuaishou_v3_x7plus_20261030.js` | 手机端 AutoJs 脚本（轮询指令 + 无障碍翻页） |

## 架构

```
ctl_x7plus.bat start
      │
      ▼
phone_ctl_server.py  :8001  ── 指令队列 / 自动上滑循环
      ▲                  │
      │ 手机轮询 /cmd     │ GET /set?cmd=up
      │ 回报 /ack         ▼
remote_ctl_kuaishou_v3_x7plus_20261030.js（手机端）
      │
      └─ 无障碍 scrollForward() → 页面指纹校验 → 回报「已换页」
```

连接方向是 **手机 → PC**，所以手机 IP 变化不影响，只有 PC 的 IP 变化时需要改脚本第 24 行 `var PC`。

## 部署步骤

### 1. 安装 AutoJs

手机装 **AutoJs 4.1.1**（armeabi-v7a），首次打开允许存储权限。

### 2. 推送脚本

```bash
adb push remote_ctl_kuaishou_v3_x7plus_20261030.js /sdcard/脚本/
```

### 3. 开启无障碍（可用 ADB 免手动）

```bash
adb shell settings put secure enabled_accessibility_services org.autojs.autojs/com.stardust.autojs.core.accessibility.AccessibilityService
adb shell settings put secure accessibility_enabled 1
```

### 4. 启动脚本

```bash
adb shell am start -n org.autojs.autojs/.external.open.RunIntentActivity \
  -a android.intent.action.VIEW \
  -d "file:///sdcard/脚本/remote_ctl_kuaishou_v3_x7plus_20261030.js" \
  -t "text/plain"
```

### 5. 启动 PC 服务

```
ctl_x7plus.bat start          # 随机 3~10 秒自动上滑
ctl_x7plus.bat start 10       # 固定 10 秒
ctl_x7plus.bat status         # 查看状态与最近回报
ctl_x7plus.bat stop           # 停止
```

脚本跑起来后会在服务端 `/info` 里显示「手机最近连接」为手机 IP。

## 单一指令接口

```
GET /set?cmd=up          上滑（覆盖未取走的指令）
GET /set?cmd=down        下滑
GET /set?cmd=tap&arg=x,y 点击坐标
GET /set?cmd=back        返回键
GET /set?cmd=home        回桌面
GET /set?cmd=scan        重新扫描节点
GET /set?cmd=status      取当前状态
GET /auto/start          开启自动上滑循环
GET /auto/stop           关闭自动上滑循环
GET /tail?n=6            最近 N 条手机回报
```

## i管家保活配置（Funtouch 5.1 必须做）

否则系统清理后台会杀掉 AutoJs，无障碍被回收，脚本静默退出。

| 配置项 | 路径 | 目标 |
|---|---|---|
| 后台高耗电白名单 | i管家 → 省电管理 → 后台高耗电 | Auto.js 打开开关 |
| 自启动 | i管家 → 软件管理 → 自启动管理 | Auto.js 移入「已允许」 |
| 悬浮窗 | i管家 → 软件管理 → 悬浮窗管理 | Auto.js 移入「允许显示」 |

这些项都可以用 `adb shell uiautomator dump` 抓控件坐标 + `adb shell input tap` 精准点击，无需人工操作。

## 已知问题与处理

**1. `force-stop` 会清空无障碍设置**

`adb shell am force-stop org.autojs.autojs` 之后，`accessibility_enabled` 会被此 ROM 重置为 0。重新启动脚本前必须重跑第 3 步的两条 `settings put` 命令。日常使用不要 force-stop AutoJs 进程，只停脚本。

**2. 前台不是目标应用时报「取树失败 种子=null」**

脚本靠 `我 / 首页 / 精选 / 同城…` 等种子文字定位无障碍树根。前台是桌面或设置页时找不到种子，属于正常保护，不是故障。

**3. 图文帖只左右翻图的修复（v3.1）**

候选容器按「信息流标记 → 竖向类名 → 深度」排序，跳过横向容器（图片轮播 / ViewPager），滑动后用页面指纹复查，内容没变就换下一个候选。

## 与 vivo X6s A 方案的差异

| | X6s A | X7Plus |
|---|---|---|
| 端口 | 8000 | **8001** |
| 控制台 | `ctl.bat` | `ctl_x7plus.bat` |
| 日志 | `phone_ack.log` | `phone_ack_x7plus.log` |
| 手机脚本 | `remote_ctl_kuaishou_v3_20261029.js` | `remote_ctl_kuaishou_v3_x7plus_20261030.js` |

两套服务端代码相同，靠端口与 `PCS_ACK_LOG` 环境变量隔离，可以同时运行，互不抢指令。
