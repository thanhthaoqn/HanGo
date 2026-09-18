FROM eclipse-temurin:17-jdk-alpine AS build

WORKDIR /workspace

COPY .mvn .mvn
COPY mvnw pom.xml ./
RUN chmod +x mvnw
RUN ./mvnw -B dependency:go-offline --no-transfer-progress

COPY src src
RUN ./mvnw -B clean package -DskipTests --no-transfer-progress

FROM eclipse-temurin:17-jre-alpine AS runtime

WORKDIR /app

COPY --from=build /workspace/target/hango-backend-0.0.1-SNAPSHOT.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
