(defproject benchmark-clojure "0.1.0"
  :dependencies [[org.clojure/clojure "1.12.0"]
                 [http-kit "2.8.0"]
                 [compojure "1.7.1"]
                 [cheshire "5.13.0"]
                 [org.postgresql/postgresql "42.7.4"]
                 [com.zaxxer/HikariCP "6.0.0"]
                 [ring/ring-json "0.5.1"]]
  :main benchmark.core
  :aot [benchmark.core]
  :uberjar-name "benchmark.jar")
