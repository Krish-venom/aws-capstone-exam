############################################
# Auto-generate all Ansible files from Terraform
############################################

# ---- Variables for app source (no hardcoding) ----
variable "app_repo_url" {
  description = "HTTPS URL of your GitHub repo that contains app/v1 and app/v2"
  type        = string
}

variable "app_src_version" {
  description = "Which app version to deploy (app/v1 or app/v2)"
  type        = string
  default     = "app/v1"
}

# ---- Local paths and file contents ----
locals {
  ansible_dir = "${path.module}/../ansible"

  hosts_ini = "[web]\n${join("\n", [for ip in aws_instance.web[*].public_ip : "${ip} ansible_user=ubuntu"])}\n"

  group_vars_all = <<-YAML
    app_repo_url: "${var.app_repo_url}"
    app_src_version: "${var.app_src_version}"
    document_root: "/var/www/html"

    rds_endpoint: "${aws_db_instance.mysql.address}"
    db_user: "${aws_db_instance.mysql.username}"
    db_pass: "${random_password.db_password.result}"
    db_name: "${aws_db_instance.mysql.db_name}"

    alb_dns_name: "${aws_lb.app.dns_name}"
  YAML

  ansible_cfg = <<-INI
    [defaults]
    inventory = hosts.ini
    host_key_checking = False
    retry_files_enabled = False
    forks = 10
    timeout = 30
  INI

  site_yml = <<-YML
    ---
    - name: Configure and deploy StreamLine web app (auto-generated)
      hosts: web
      become: yes
      roles:
        - web
  YML

  role_tasks_main = <<-YML
    ---
    - name: Update apt cache
      ansible.builtin.apt:
        update_cache: yes
        cache_valid_time: 3600

    - name: Install Apache/PHP/MySQL client/Git
      ansible.builtin.apt:
        name:
          - apache2
          - libapache2-mod-php
          - php
          - php-mysql
          - git
          - mysql-client
        state: present

    - name: Ensure Apache is enabled and running
      ansible.builtin.service:
        name: apache2
        state: started
        enabled: yes

    - name: Ensure document root exists
      ansible.builtin.file:
        path: "{{ document_root }}"
        state: directory
        owner: www-data
        group: www-data
        mode: "0755"

    - name: Checkout application repo
      ansible.builtin.git:
        repo: "{{ app_repo_url }}"
        dest: /opt/app
        version: main
        force: yes

    - name: Deploy selected version to document root
        # trailing '/.' preserves hidden files; use /bin/bash for globbing
      ansible.builtin.shell: cp -a /opt/app/{{ app_src_version }}/. {{ document_root }}/
      args:
        executable: /bin/bash

    - name: Create db_check.php for RDS connectivity test
      ansible.builtin.template:
        src: "db_check.php.j2"
        dest: "{{ document_root }}/db_check.php"
        mode: "0644"
        owner: www-data
        group: www-data

    - name: Ensure DB exists
      ansible.builtin.shell: >
        mysql -h {{ rds_endpoint }} -u {{ db_user }}
        -p'{{ db_pass }}'
        -e "CREATE DATABASE IF NOT EXISTS {{ db_name }};"
      register: create_db_result
      changed_when: "'ERROR' not in create_db_result.stderr"

    - name: Set ownership for document root
      ansible.builtin.file:
        path: "{{ document_root }}"
        owner: www-data
        group: www-data
        recurse: yes

    - name: Reload Apache
      ansible.builtin.service:
        name: apache2
        state: reloaded
  YML

  db_check_template = <<-PHP
    <?php
    $host = "{{ rds_endpoint }}";
    $user = "{{ db_user }}";
    $pass = "{{ db_pass }}";
    $db   = "{{ db_name }}";

    header('Content-Type: text/plain');

    $mysqli = @new mysqli($host, $user, $pass, $db);

    if ($mysqli->connect_errno) {
      http_response_code(500);
      echo "Database Connection Failed: (" . $mysqli->connect_errno . ") " . $mysqli->connect_error;
      exit;
    }

    echo "Database Connected Successfully";
    $mysqli->close();
  PHP

  deploy_sh = <<-SH
    #!/usr/bin/env bash
    set -euo pipefail
    cd "$(dirname "$0")"
    KEY="../terraform/generated_${var.project}_key.pem"
    echo "Using key: $KEY"
    ansible -i hosts.ini all -m ping -u ubuntu --key-file "$KEY"
    ansible-playbook -i hosts.ini site.yml -u ubuntu --key-file "$KEY"
  SH
}

# ---- Ensure ansible directories exist ----
resource "null_resource" "prepare_ansible_dirs" {
  provisioner "local-exec" {
    command = <<-CMD
      mkdir -p "${local.ansible_dir}/group_vars" \
               "${local.ansible_dir}/roles/web/tasks" \
               "${local.ansible_dir}/roles/web/templates"
    CMD
  }
}

# ---- Write all Ansible artifacts from live TF values ----
resource "local_file" "ansible_hosts" {
  depends_on = [null_resource.prepare_ansible_dirs, aws_instance.web]
  filename   = "${local.ansible_dir}/hosts.ini"
  content    = local.hosts_ini
  file_permission = "0644"
}

resource "local_file" "ansible_group_vars" {
  depends_on = [null_resource.prepare_ansible_dirs, aws_db_instance.mysql, aws_lb.app]
  filename   = "${local.ansible_dir}/group_vars/all.yml"
  content    = trim(local.group_vars_all)
  file_permission = "0600"
}

resource "local_file" "ansible_cfg" {
  depends_on = [null_resource.prepare_ansible_dirs]
  filename   = "${local.ansible_dir}/ansible.cfg"
  content    = trim(local.ansible_cfg)
  file_permission = "0644"
}

resource "local_file" "site_yml" {
  depends_on = [null_resource.prepare_ansible_dirs]
  filename   = "${local.ansible_dir}/site.yml"
  content    = trim(local.site_yml)
  file_permission = "0644"
}

resource "local_file" "role_tasks_main" {
  depends_on = [null_resource.prepare_ansible_dirs]
  filename   = "${local.ansible_dir}/roles/web/tasks/main.yml"
  content    = trim(local.role_tasks_main)
  file_permission = "0644"
}

resource "local_file" "role_template_dbcheck" {
  depends_on = [null_resource.prepare_ansible_dirs]
  filename   = "${local.ansible_dir}/roles/web/templates/db_check.php.j2"
  content    = trim(local.db_check_template)
  file_permission = "0644"
}

resource "local_file" "deploy_script" {
  depends_on = [null_resource.prepare_ansible_dirs, local_file.ansible_hosts]
  filename   = "${local.ansible_dir}/deploy.sh"
  content    = trim(local.deploy_sh)
  file_permission = "0755"
}
