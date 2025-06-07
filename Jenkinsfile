pipeline {
    agent any
    environment {
        IMAGE_NAME = 'my-spring-app'
        IMAGE_TAG = 'latest'
        CONTAINER_NAME = 'my-spring-app'
        HOST_LOG_DIR = '/home/ubuntu/spring-app-logs' // 호스트의 로그 디렉토리 경로
        CONTAINER_LOG_DIR = '/app/logs' // 컨테이너의 로그 디렉토리 경로
        BLUE_CONTAINER_NAME = 'my-spring-app-blue'
        BLUE_CONTAINER_PORT = '8090'
        GREEN_CONTAINER_NAME = 'my-spring-app-green'
        GREEN_CONTAINER_PORT = '8091'

        NGINX_CONF_FILE = '/etc/nginx/sites-available/default'
        SSH_USER = 'ubuntu'             // EC2 인스턴스의 SSH 사용자 이름
    }
    stages {
        // 브랜치에 따라 환경변수값을 다르게 설정하는 위치
        stage('Set Environment Variables') {
            steps {
                script {
                     // 멀티브랜치 파이프라인이 아니더라도 사용 가능한 GIT_BRANCH 변수로 브랜치면 가져오기
                     env.BRANCH_NAME = env.GIT_BRANCH?.replaceAll('^origin/', '')

                    // 브랜치가 'main'인 경우 (운영 환경)
                    if (env.BRANCH_NAME == 'main') {
                        //---------------------------------------실제 운영환경 세팅 필요-----------------------------------------------------

                        // TODO: 운영 환경에 사용할 EC2 인스턴스의 호스트 주소를 설정
                        env.EC2_HOST = '3.35.2.191'
                        // TODO: 운영 환경에서 사용될 SSH 키 경로 설정
                        env.SSH_KEY = '/var/jenkins_home/.ssh/woosung-ec2-key.pem'

                        //---------------------------------------------------------------------------------------------------------------
                        // 운영 환경에서 사용할 스프링 프로파일을 'prod'로 설정
                        env.SPRING_PROFILES_ACTIVE = 'prod'
                    }
                    // 브랜치가 'dev' 또는 'develop'인 경우 (개발 환경)
                    else if (env.BRANCH_NAME == 'dev' || env.BRANCH_NAME == 'develop') {
                        //---------------------------------------개발환경 세팅 필요----------------------------------------------------------

                        // TODO: 개발 환경에 사용할 EC2 인스턴스의 호스트 주소를 설정
                        env.EC2_HOST = ''
                        // TODO: 개발 환경에서 사용될 SSH 키 경로 설정
                        env.SSH_KEY = '/var/jenkins_home/.ssh/'

                        //---------------------------------------------------------------------------------------------------------------
                        // 개발 환경에서 사용할 스프링 프로파일을 'dev'로 설정
                        env.SPRING_PROFILES_ACTIVE = 'dev'
                    }
                    echo "BRANCH_NAME is set to: ${env.BRANCH_NAME}"
                    echo "EC2_HOST is set to: ${env.EC2_HOST}"
                    echo "SSH_KEY is set to: ${env.SSH_KEY}"
                }
            }
        }
        stage('Notify Start') {
            steps {
                script {
                    // Git 변경내역 가져오기
                    def changes = sh(
                        script: 'git log --pretty=format:"%h - %an, %ar : %s" HEAD~5..HEAD || echo "No previous commits found."',
                        returnStdout: true
                    ).trim()
                    slackSend(color: 'warning', message: """
-------------------------------------------------------------------------------------------\n\n
Last 5 commits:\n
${changes}\n
                    Build Started: ${env.JOB_NAME} [${env.BUILD_NUMBER}]
                    (<${env.BUILD_URL}|진행중인 빌드 보러가기>)
                    """)
                }
            }
        }
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        stage('Prepare') {
            steps {
                sh 'chmod +x ./gradlew'
            }
        }
        stage('Build & Test') {
            steps {
                sh './gradlew clean build test'
            }
        }
        stage('Prepare Docker') {
            steps {
                script {
                    // Docker 소켓의 권한을 변경
                    sh 'sudo chmod 666 /var/run/docker.sock'
                }
            }
        }
        stage('Build Docker Image') {
            steps {
                script {
                    slackSend(color: 'good', message: "도커 이미지 빌드 시작...")

                    // 새로운 이미지 빌드 -> 기존에 같은 이름의 이미지가 있으면 새로 만든게 이름을 갖고 기존은 이름이 없어진다.
                    // Docker 빌드 시 profile 값을 전달
                    sh "docker build --build-arg SPRING_PROFILES_ACTIVE=${env.SPRING_PROFILES_ACTIVE} -t ${env.IMAGE_NAME}:${env.IMAGE_TAG} -f Dockerfile ."

                    slackSend(color: 'good', message: "도커 이미지 빌드 완료")
                }
            }
        }
        stage('Deploy') {
            steps {
                script {
                    // 현재 활성화된 컨테이너 확인(my-spring-app 이름을 포함하는 컨테이너 확인)
                    def activeContainer = sh(script: "docker ps --filter 'name=my-spring-app' --format '{{.Names}}'", returnStdout: true).trim()

                    // (기존 8090을 사용할때를 고려하여 8091 부터 시작하도록 함)
                    def newContainerName = (activeContainer == env.GREEN_CONTAINER_NAME) ? env.BLUE_CONTAINER_NAME : env.GREEN_CONTAINER_NAME
                    def newContainerPort = (activeContainer == env.GREEN_CONTAINER_NAME) ? env.BLUE_CONTAINER_PORT : env.GREEN_CONTAINER_PORT

                    // 기존 실행되고 있는 컨테이너의 포트
                    def oldContainerPort = (activeContainer == env.GREEN_CONTAINER_NAME) ? env.GREEN_CONTAINER_PORT : env.BLUE_CONTAINER_PORT

                    // 새로운 컨테이너 시작
                    sh "docker run -d -p ${newContainerPort}:8090 --name ${newContainerName} -v ${env.HOST_LOG_DIR}:${env.CONTAINER_LOG_DIR} ${env.IMAGE_NAME}:${env.IMAGE_TAG}"
                    slackSend(color: 'good', message: "New container starting...")

                    // 새 컨테이너가 정상적으로 시작되었는지 확인
                    def maxRetries = 10
                    def currentRetry = 1
                    def newContainerStatus = ""

                    // 10초마다 체크 10번까지 체크
                    while (currentRetry <= maxRetries) {
                        sleep 10
                        newContainerStatus = sh(script: "docker inspect -f '{{.State.Health.Status}}' ${newContainerName}", returnStdout: true).trim()
                        slackSend(color: 'warning', message: "New container status (attempt [${currentRetry} / ${maxRetries}]): ${newContainerStatus}")
                        if (newContainerStatus == 'healthy') {
                            slackSend(color: 'good', message: "New container started successfully, it is healthy now")
                            break
                        }
                        currentRetry++
                    }

                    if (newContainerStatus == 'healthy') {
                        // nginx 설정 파일의 권한을 변경(꼭 필요한지 모르겠음)
                        sh "ssh -i ${env.SSH_KEY} -o StrictHostKeyChecking=no ${env.SSH_USER}@${env.EC2_HOST} 'sudo chmod 666 /etc/nginx/sites-available/default'"

                        // nginx 설정으로 새로운 컨테이너의 포트를 가리키도록 설정(ssh로 접속하여 설정 변경)
                        sh "ssh -i ${env.SSH_KEY} -o StrictHostKeyChecking=no ${env.SSH_USER}@${env.EC2_HOST} 'sudo sed -i \"s/proxy_pass http:\\/\\/localhost:.*/proxy_pass http:\\/\\/localhost:${newContainerPort};/\" ${env.NGINX_CONF_FILE}'"
                        sh "ssh -i ${env.SSH_KEY} -o StrictHostKeyChecking=no ${env.SSH_USER}@${env.EC2_HOST} 'sudo nginx -t && sudo systemctl reload nginx'"


                        slackSend(color: 'good', message: "Nginx 라우팅 변경 완료[${oldContainerPort} -> ${newContainerPort}]")

                        // 기존 컨테이너 중지 및 제거
                        if (activeContainer) { // 첫 배포시 activeContainer 가 빈 문자열일수도 있음.
                            // stop 명령시 애플리케이션이 정상 종료되고 컨테이너가 중지된다(해당 라인이 완료되어야 다음라인으로 진행되기 때문에, 따로 sleep 을 주어 기다려줄 필요 없다.)
                            sh "docker stop ${activeContainer} || true"
                            sh "docker rm ${activeContainer} || true"
                        }

                        // 사용되지 않는 이미지 정리
                        sh "docker image prune -f"

                        slackSend(color: 'good', message: "기존 이미지, 컨테이너 정리 완료")
                    } else {
                        // 새 컨테이너가 비정상일 경우 롤백
                        sh "docker stop ${newContainerName} || true"
                        sh "docker rm ${newContainerName} || true"

                        // 사용되지 않는 이미지 정리
                        sh "docker image prune -f"

                        slackSend(color: 'danger', message: "빌드 실패... 이전 빌드로 롤백 완료")

                        // error 명령을 통해 failure 블럭으로 이동
                        error "New container failed to start, rolled back to previous version"
                    }
                }
            }
        }
    }
    post {
        success {
            slackSend(color: 'good', message: """결과:\n\n
                    Build Successful: ${env.JOB_NAME} [${env.BUILD_NUMBER}]
                    (<${env.BUILD_URL}|빌드 결과 확인하기>)
-------------------------------------------------------------------------------------------
            """)
        }
        failure {
            slackSend(color: 'danger', message: """결과:\n\n
                    Build Failed: ${env.JOB_NAME} [${env.BUILD_NUMBER}]
                    (<${env.BUILD_URL}|큰일 났다...!>)
-------------------------------------------------------------------------------------------
            """)
        }
    }
}