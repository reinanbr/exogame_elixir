;;;; Benchmark Common Lisp server using Hunchentoot + Postmodern/cl-postgres
;;;; API: POST /items, GET /items/:id, WS /ws

(ql:quickload '(:hunchentoot :hunchensocket :postmodern :cl-json :bordeaux-threads) :silent t)

(defpackage :benchmark-lisp
  (:use :cl :hunchentoot :hunchensocket))
(in-package :benchmark-lisp)

;;; ── Database ─────────────────────────────────────────────────────────
(defun db-host ()
  (or (uiop:getenv "DB_HOST") "postgres"))

(defun connect-db ()
  (loop for attempt from 1 to 30
        do (handler-case
               (progn
                 (postmodern:connect-toplevel "bench" "bench" "bench" (db-host) :port 5432)
                 (format t "Connected to PostgreSQL~%")
                 (return t))
             (error (e)
               (format t "DB not ready (~a/30): ~a~%" attempt e)
               (sleep 1))))
  ;; Enable connection pool
  (setf postmodern:*max-pool-size* 16))

;;; ── WebSocket Hub ────────────────────────────────────────────────────
(defvar *ws-clients* (make-hash-table :test 'eq))
(defvar *ws-lock* (bt:make-lock "ws-hub"))

(defclass bench-ws-resource (hunchensocket:websocket-resource) ()
  (:default-initargs :client-class 'hunchensocket:websocket-client))

(defmethod hunchensocket:client-connected ((resource bench-ws-resource) client)
  (bt:with-lock-held (*ws-lock*)
    (setf (gethash client *ws-clients*) t)))

(defmethod hunchensocket:client-disconnected ((resource bench-ws-resource) client)
  (bt:with-lock-held (*ws-lock*)
    (remhash client *ws-clients*)))

(defmethod hunchensocket:text-message-received ((resource bench-ws-resource) client message)
  (declare (ignore client))
  (bt:with-lock-held (*ws-lock*)
    (maphash (lambda (ws _)
               (declare (ignore _))
               (handler-case (hunchensocket:send-text-message ws message)
                 (error () nil)))
             *ws-clients*)))

(defvar *ws-resource* (make-instance 'bench-ws-resource))

(defun ws-dispatcher (request)
  (when (string= (hunchentoot:script-name request) "/ws")
    *ws-resource*))

(pushnew 'ws-dispatcher hunchensocket:*websocket-dispatch-table*)

;;; ── JSON helpers ─────────────────────────────────────────────────────
(defun item-to-json (id name value)
  (cl-json:encode-json-to-string
   `((:id . ,id) (:name . ,name) (:value . ,value))))

(defun parse-json-body (body)
  (cl-json:decode-json-from-string body))

(defun aget (key alist)
  (cdr (assoc key alist :test #'string-equal)))

;;; ── HTTP Handlers ────────────────────────────────────────────────────
(define-easy-handler (post-items :uri "/items" :default-request-type :post) ()
  (setf (content-type*) "application/json")
  (let* ((body (hunchentoot:raw-post-data :force-text t))
         (json (handler-case (parse-json-body body)
                 (error () nil))))
    (unless json
      (setf (return-code*) +http-bad-request+)
      (return-from post-items "{\"error\":\"invalid json\"}"))
    (let ((name (cdr (assoc :name json)))
          (value (or (cdr (assoc :value json)) "")))
      (unless name
        (setf (return-code*) +http-bad-request+)
        (return-from post-items "{\"error\":\"missing name\"}"))
      (let ((rows (postmodern:query
                   "INSERT INTO items (name, value) VALUES ($1, $2) RETURNING id, name, value"
                   name value :rows)))
        (when rows
          (let ((row (first rows)))
            (setf (return-code*) +http-created+)
            (item-to-json (first row) (second row) (third row))))))))

(defun handle-get-item ()
  (setf (content-type*) "application/json")
  (let* ((uri (hunchentoot:request-uri*))
         (id-str (subseq uri 7)) ; skip "/items/"
         (id (handler-case (parse-integer id-str)
               (error () nil))))
    (unless id
      (setf (return-code*) +http-bad-request+)
      (return-from handle-get-item "{\"error\":\"invalid id\"}"))
    (let ((rows (postmodern:query
                 "SELECT id, name, value FROM items WHERE id=$1" id :rows)))
      (if rows
          (let ((row (first rows)))
            (item-to-json (first row) (second row) (third row)))
          (progn
            (setf (return-code*) +http-not-found+)
            "{\"error\":\"not found\"}")))))

;;; Custom dispatcher for GET /items/:id
(push (create-regex-dispatcher "^/items/\\d+$" 'handle-get-item)
      *dispatch-table*)

;;; ── Main ─────────────────────────────────────────────────────────────
(defun main ()
  (connect-db)
  (format t "Common Lisp/Hunchentoot server starting on :8080~%")
  (let ((server (make-instance 'hunchensocket:websocket-acceptor
                               :port 8080
                               :address "0.0.0.0")))
    (hunchentoot:start server)
    ;; Keep running
    (loop (sleep 3600))))

(main)
