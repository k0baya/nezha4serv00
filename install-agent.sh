#!/bin/bash

USERNAME=$(whoami)
WORKDIR="/home/${USERNAME}/.nezha-agent"

# 下载 nezha-agent 的函数
download_agent() {
    DOWNLOAD_LINK="https://github.com/nezhahq/agent/releases/latest/download/nezha-agent_freebsd_amd64.zip"
    if ! wget -qO "$ZIP_FILE" "$DOWNLOAD_LINK"; then
        echo 'error: Download failed! Please check your network or try again.'
        return 1
    fi
    return 0
}

# 解压函数
decompression() {
    unzip "$1" -d "$TMP_DIRECTORY"
    EXIT_CODE=$?
    if [ ${EXIT_CODE} -ne 0 ]; then
        rm -r "$TMP_DIRECTORY"
        echo "removed: $TMP_DIRECTORY"
        exit 1
    fi
}

# 安装 nezha-agent 的函数
install_agent() {
    install -m 755 ${TMP_DIRECTORY}/nezha-agent ${WORKDIR}/nezha-agent
}

# 生成 config.yml 的函数
generate_config() {
    CONFIG_PATH="${WORKDIR}/config.yml"
    cat > "$CONFIG_PATH" << EOF
client_secret: ${NZ_DASHBOARD_PASSWORD}
debug: false
disable_auto_update: false
disable_command_execute: false
disable_force_update: false
disable_nat: false
disable_send_query: false
gpu: false
insecure_tls: false
ip_report_period: 1800
report_delay: 1
server: ${NZ_DASHBOARD_SERVER}:${NZ_DASHBOARD_PORT}
skip_connection_count: false
skip_procs_count: false
temperature: false
tls: ${NZ_GRPC_PROXY}
use_gitee_to_upgrade: false
use_ipv6_country_code: false
uuid: 
EOF
    echo "config.yml 已成功生成到 ${CONFIG_PATH}"
}

# 生成启动脚本的函数
generate_run_agent() {
    echo "关于接下来需要输入的三个变量，请注意："
    echo "Dashboard 站点地址可以写 IP 也可以写域名（域名不可套 CDN）；但不要加 http:// 或 https:// 前缀，直接写 IP 或域名即可。"
    echo "面板 RPC 端口为你的 Dashboard 安装时设置的用于 Agent 接入的 RPC 端口（默认 5555）。"
    echo "Agent 密钥需要先在管理面板上添加 Agent 获取。"
    printf "请输入 Dashboard 站点地址："
    read -r NZ_DASHBOARD_SERVER
    printf "请输入面板 RPC 端口："
    read -r NZ_DASHBOARD_PORT
    printf "请输入 Agent 密钥: "
    read -r NZ_DASHBOARD_PASSWORD
    printf "是否启用针对 gRPC 端口的 SSL/TLS加密 (--tls)，需要请按 [Y]，默认是不需要，不理解的用户可回车跳过: "
    read -r NZ_GRPC_PROXY
    echo "${NZ_GRPC_PROXY}" | grep -qiw 'Y' && NZ_GRPC_PROXY=true || NZ_GRPC_PROXY=false

    if [ -z "${NZ_DASHBOARD_SERVER}" ] || [ -z "${NZ_DASHBOARD_PASSWORD}" ]; then
        echo "error! 所有选项都不能为空"
        return 1
        rm -rf ${WORKDIR}
        exit
    fi

    generate_config

    cat > ${WORKDIR}/start.sh << EOF
#!/bin/bash
pgrep -f 'nezha-agent' | xargs -r kill
cd ${WORKDIR}
TMPDIR="${WORKDIR}" exec ${WORKDIR}/nezha-agent -c config.yml >/dev/null 2>&1
EOF
    chmod +x ${WORKDIR}/start.sh
}

# 启动 nezha-agent 的函数
run_agent() {
    nohup ${WORKDIR}/start.sh >/dev/null 2>&1 &
    printf "nezha-agent已经准备就绪，请按下回车键启动\n"
    read
    printf "正在启动nezha-agent，请耐心等待...\n"
    sleep 3
    if pgrep -f "nezha-agent -c" > /dev/null; then
        echo "nezha-agent 已启动！"
        echo "如果面板处未上线，请检查参数是否填写正确，并停止 agent 进程，删除已安装的 agent 后重新安装！"
        echo "停止 agent 进程的命令：pgrep -f 'nezha-agent' | xargs -r kill"
        echo "删除已安装的 agent 的命令：rm -rf ~/.nezha-agent"
        echo
        echo "如果你想使用 pm2 管理 agent 进程，请执行：pm2 start ~/.nezha-agent/start.sh --name nezha-agent"
    else
        rm -rf "${WORKDIR}"
        echo "nezha-agent 启动失败，请检查参数填写是否正确，并重新安装！"
    fi
}

# 主程序
mkdir -p ${WORKDIR}
cd ${WORKDIR}
TMP_DIRECTORY="$(mktemp -d)"
ZIP_FILE="${TMP_DIRECTORY}/nezha-agent_freebsd_amd64.zip"

[ ! -e ${WORKDIR}/start.sh ] && generate_run_agent
[ ! -e ${WORKDIR}/nezha-agent ] && download_agent \
&& decompression "${ZIP_FILE}" \
&& install_agent

rm -rf "${TMP_DIRECTORY}"
[ -e ${WORKDIR}/start.sh ] && run_agent
