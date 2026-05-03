pipeline {
  agent any

  stages {

    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Syntax Check') {
      steps {
        sh 'ansible-playbook lab1/iti-webserver/site.yml --syntax-check'
        sh 'ansible-playbook lab2/lab2/site.yml --syntax-check'
        sh 'ansible-playbook lab2/mariadb-server/site.yml --syntax-check'
      }
    }

    stage('Lint') {
      steps {
        sh 'pip3 install ansible-lint -q'
        sh 'ansible-lint lab1/iti-webserver/site.yml || true'
        sh 'ansible-lint lab2/lab2/site.yml || true'
      }
    }

  }

  post {
    success {
      echo 'Pipeline passed! All Ansible playbooks are valid.'
    }
    failure {
      echo 'Pipeline failed — check the logs above.'
    }
  }
}
