# sdk
sdk packages

这是一个SDK相关的软件包索引仓库，用于放置工具链，QEMU模拟器等的软件包。这些软件包括可以通过RT-Thread Env系统来安装。

## 如何使用

在Windows平台上，当激活env 2的Python虚拟化环境后，可以在powershell中输入sdk进入到选择菜单中；

在Linux平台上，可以通过如下方式激活选择菜单：

```bash
source <env_path>/env.sh
sdk
```

其中 `<env_path>` 是您的 env 目录路径。

当重新配置后，会自动下载并部署对应的工具链。注意：工具链下载可能需要耐心等待一段时间(有下载及展开部署进度条)。
