FROM sbtscala/scala-sbt:eclipse-temurin-21.0.4_7_1.10.1_3.4.2 AS build
WORKDIR /app
COPY build.sbt .
COPY project/ ./project/
RUN sbt update
COPY src/ ./src/
RUN sbt assembly

FROM eclipse-temurin:21-jre-jammy
WORKDIR /app
COPY --from=build /app/target/scala-3.4.2/benchmark-scala-assembly-0.1.0.jar ./app.jar
EXPOSE 8080
CMD ["java", "-jar", "app.jar"]
