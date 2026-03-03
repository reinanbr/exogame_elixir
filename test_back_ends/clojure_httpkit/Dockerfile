FROM clojure:temurin-21-lein AS build
WORKDIR /app
COPY project.clj .
RUN lein deps
COPY src/ ./src/
RUN lein uberjar

FROM eclipse-temurin:21-jre-jammy
WORKDIR /app
COPY --from=build /app/target/benchmark.jar .
EXPOSE 8080
CMD ["java", "-jar", "benchmark.jar"]
