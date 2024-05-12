FROM openjdk:17
WORKDIR /app
COPY ./build/libs/*.jar app.jar

# 기본값으로 dev를 설정해두지만, 외부에서 다른 값으로 덮어쓸 수 있음
ENV SPRING_PROFILES_ACTIVE=dev

# 헬스 체크 설정
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 CMD curl -f http://localhost:8090/actuator/health || exit 1

ENTRYPOINT ["java", "-Dspring.profiles.active=${SPRING_PROFILES_ACTIVE}", "-Dserver.port=8090", "-jar", "app.jar"]