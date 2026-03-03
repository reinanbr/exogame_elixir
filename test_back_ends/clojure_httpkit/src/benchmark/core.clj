(ns benchmark.core
  (:require [org.httpkit.server :as http]
            [compojure.core :refer [defroutes POST GET]]
            [compojure.route :as route]
            [ring.middleware.json :refer [wrap-json-body wrap-json-response]]
            [cheshire.core :as json])
  (:import [com.zaxxer.hikari HikariConfig HikariDataSource]
           [java.sql DriverManager])
  (:gen-class))

;; ── Database ──────────────────────────────────────────────────────────
(defonce ^:private ds (atom nil))

(defn init-db! []
  (let [host (or (System/getenv "DB_HOST") "postgres")]
    (loop [attempt 1]
      (if (> attempt 30)
        (throw (Exception. "Failed to connect to DB after 30 retries"))
        (let [url (str "jdbc:postgresql://" host ":5432/bench")]
          (try
            (let [config (doto (HikariConfig.)
                           (.setJdbcUrl url)
                           (.setUsername "bench")
                           (.setPassword "bench")
                           (.setMaximumPoolSize 16)
                           (.setMinimumIdle 4))]
              (reset! ds (HikariDataSource. config))
              (println "Connected to PostgreSQL"))
            (catch Exception e
              (println (str "DB not ready (" attempt "/30): " (.getMessage e)))
              (Thread/sleep 1000)
              (recur (inc attempt)))))))))

(defn get-conn [] (.getConnection ^HikariDataSource @ds))

;; ── WebSocket Hub ─────────────────────────────────────────────────────
(defonce ws-clients (atom #{}))

(defn ws-handler [req]
  (http/with-channel req channel
    (swap! ws-clients conj channel)
    (http/on-close channel
      (fn [_status]
        (swap! ws-clients disj channel)))
    (http/on-receive channel
      (fn [msg]
        (doseq [c @ws-clients]
          (try (http/send! c msg) (catch Exception _ nil)))))))

;; ── HTTP handlers ─────────────────────────────────────────────────────
(defn handle-post-items [req]
  (let [{:strs [name value]} (:body req)
        value (or value "")]
    (if (nil? name)
      {:status 400 :body {:error "missing name"}}
      (with-open [conn (get-conn)]
        (let [ps (.prepareStatement conn
                   "INSERT INTO items (name, value) VALUES (?, ?) RETURNING id, name, value")]
          (.setString ps 1 name)
          (.setString ps 2 value)
          (let [rs (.executeQuery ps)]
            (if (.next rs)
              {:status 201
               :body {:id (.getInt rs "id")
                      :name (.getString rs "name")
                      :value (.getString rs "value")}}
              {:status 500 :body {:error "insert failed"}})))))))

(defn handle-get-item [req]
  (let [id (try (Integer/parseInt (:id (:params req)))
                (catch Exception _ nil))]
    (if (nil? id)
      {:status 400 :body {:error "invalid id"}}
      (with-open [conn (get-conn)]
        (let [ps (.prepareStatement conn
                   "SELECT id, name, value FROM items WHERE id = ?")]
          (.setInt ps 1 id)
          (let [rs (.executeQuery ps)]
            (if (.next rs)
              {:status 200
               :body {:id (.getInt rs "id")
                      :name (.getString rs "name")
                      :value (.getString rs "value")}}
              {:status 404 :body {:error "not found"}})))))))

;; ── Routes ────────────────────────────────────────────────────────────
(defroutes app-routes
  (POST "/items" req (handle-post-items req))
  (GET "/items/:id" req (handle-get-item req))
  (GET "/ws" req (ws-handler req))
  (route/not-found {:status 404 :body {:error "not found"}}))

(def app
  (-> app-routes
      (wrap-json-body)
      (wrap-json-response)))

;; ── Main ──────────────────────────────────────────────────────────────
(defn -main [& _args]
  (init-db!)
  (println "Clojure/Http-kit server on :8080")
  (http/run-server app {:port 8080 :max-ws 120000}))
