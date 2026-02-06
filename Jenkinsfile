pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  parameters {
    choice(name: 'APP_VERSION', choices: ['app/v1', 'app/v2'], description: 'Which app version to deploy')
    booleanParam(name: 'DESTROY_AFTER', defaultValue: false, description: 'Destroy infra after deployment (for cleanup)')
  }

 /***************
   * Environment
   ***************/
  environment {
    REPO_URL = 'https://github.com/Pugazh529/aws-capstone-exam.git'   // <— your single repo
    INVENTORY_FILE = 'ansible/hosts'
    PLAYBOOK_FILE  = 'ansible/playbook.yml'
    ANSIBLE_HOST_KEY_CHECKING = 'False'
    CURL_MAX_TIME = '10'
  }
 
  /***************
   * Auto trigger on push (requires GitHub webhook to Jenkins)
   ***************/
  triggers {
    githubPush()
  }
 
  stages {
 
    stage('Checkout (single repo)') {
      steps {
        cleanWs()
        git branch: params.BRANCH, credentialsId: 'git-id', url: env.REPO_URL
      }
    }
 
    stage('Validate Ansible files') {
      steps {
        sh '''
          set -e
          echo "Checking required files..."
          test -f "${PLAYBOOK_FILE}" || { echo "Missing ${PLAYBOOK_FILE}"; exit 1; }
          test -f "${INVENTORY_FILE}" || { echo "Missing ${INVENTORY_FILE}"; exit 1; }
          echo "---- Inventory (${INVENTORY_FILE}) ----"
          cat "${INVENTORY_FILE}"
        '''
      }
    }
 
stage('Deploy with Ansible') {
  steps {
    withCredentials([sshUserPrivateKey(credentialsId: 'vm-id',
                                      keyFileVariable: 'PK',
                                      usernameVariable: 'SSH_USER')]) {
      sh """#!/usr/bin/env bash
set -Eeuo pipefail
 
chmod 600 "$PK"
 
# Decide app source path automatically.
APP_PATH="${WORKSPACE}/app"
if [ ! -f "${APP_PATH}/index.html" ]; then
  APP_PATH="${WORKSPACE}"
fi
echo "Using APP_PATH=\${APP_PATH}"
 
export ANSIBLE_PRIVATE_KEY_FILE="$PK"
export ANSIBLE_HOST_KEY_CHECKING=False
 
ansible-playbook -i "${INVENTORY_FILE}" "${PLAYBOOK_FILE}" \
  --user "$SSH_USER" --private-key "$PK" \
  --extra-vars "branch=${params.BRANCH} repo_url=${REPO_URL} web_src=\${APP_PATH}" -vv
"""
    }
  }
}
 
    stage('Smoke Test (first host in inventory)') {
      steps {
        script {
          def targetHost = sh(
            returnStdout: true,
            script: '''#!/usr/bin/env bash
set -Eeuo pipefail
ansible -i "${INVENTORY_FILE}" all --list-hosts 2>/dev/null | awk 'NR>1 {print $1; exit}'
''').trim()
 
          if (!targetHost) {
            error "Could not determine a target host from ${env.INVENTORY_FILE}"
          }
 
          sh """#!/usr/bin/env bash
set -Eeuo pipefail
echo "curl http://${targetHost} ..."
curl -sS --max-time ${env.CURL_MAX_TIME} http://${targetHost} | head -n 30 || true
"""
        }
      }
    }
  }
 
  post {
    success { echo '✅ Deployment successful' }
    failure { echo '❌ Deployment failed — check the console log' }
    always  { archiveArtifacts artifacts: 'ansible/**', allowEmptyArchive: true }
  }
}
