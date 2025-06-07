# CI/CD 빌드 테스트
- 옵시디언 문서의 9번 단계(CI/CD 테스트)에서 쓰이는 프로젝트이다.

## 사전 준비할것
1. 1~8 까지의 단계를 완료한다.
2. 현재프로젝트의 Jenkinsfile 에서 IP와 Key를 수정한다.
- 아래 예시(브랜치에 따라서, main, dev 조건 블록 안쪽에 아래부분을 찾아서 변경)
```
// TODO: 운영 환경에 사용할 EC2 인스턴스의 호스트 주소를 설정
env.EC2_HOST = '실제 ip'
// TODO: 운영 환경에서 사용될 SSH 키 경로 설정
env.SSH_KEY = '/var/jenkins_home/.ssh/실제 키파일 이름'
```