use actix_web::{web, App, HttpServer, HttpRequest, HttpResponse};
use actix_ws::Message;
use deadpool_postgres::{Config, Pool, Runtime};
use futures_util::StreamExt;
use parking_lot::RwLock;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::broadcast;

// ── Data ──────────────────────────────────────────────────────────────
#[derive(Serialize, Deserialize)]
struct ItemIn { name: String, value: String }

#[derive(Serialize)]
struct ItemOut { id: i32, name: String, value: String, created_at: String }

// ── WS Hub ────────────────────────────────────────────────────────────
type Tx = broadcast::Sender<String>;
struct WsHub { topics: RwLock<HashMap<String, Tx>> }

impl WsHub {
    fn new() -> Self { Self { topics: RwLock::new(HashMap::new()) } }
    fn subscribe(&self, topic: &str) -> broadcast::Receiver<String> {
        let mut map = self.topics.write();
        let tx = map.entry(topic.to_string())
            .or_insert_with(|| broadcast::channel(65536).0);
        tx.subscribe()
    }
    fn broadcast(&self, topic: &str, msg: &str) {
        let map = self.topics.read();
        if let Some(tx) = map.get(topic) { let _ = tx.send(msg.to_string()); }
    }
}

// ── CRUD Handlers ─────────────────────────────────────────────────────
async fn create_item(pool: web::Data<Pool>, body: web::Json<ItemIn>) -> HttpResponse {
    let client = pool.get().await.unwrap();
    let row = client.query_one(
        "INSERT INTO items(name,value) VALUES($1,$2) RETURNING id,name,value,created_at::text",
        &[&body.name, &body.value],
    ).await.unwrap();
    HttpResponse::Created().json(ItemOut {
        id: row.get(0), name: row.get(1), value: row.get(2), created_at: row.get(3),
    })
}

async fn get_item(pool: web::Data<Pool>, path: web::Path<i32>) -> HttpResponse {
    let client = pool.get().await.unwrap();
    match client.query_opt(
        "SELECT id,name,value,created_at::text FROM items WHERE id=$1", &[&path.into_inner()],
    ).await.unwrap() {
        Some(row) => HttpResponse::Ok().json(ItemOut {
            id: row.get(0), name: row.get(1), value: row.get(2), created_at: row.get(3),
        }),
        None => HttpResponse::NotFound().json(serde_json::json!({"error":"not found"})),
    }
}

// ── WebSocket Handler ─────────────────────────────────────────────────
async fn ws_handler(
    req: HttpRequest,
    body: web::Payload,
    hub: web::Data<Arc<WsHub>>,
) -> actix_web::Result<HttpResponse> {
    let (resp, mut session, mut stream) = actix_ws::handle(&req, body)?;
    let hub = hub.get_ref().clone();

    actix_web::rt::spawn(async move {
        let mut rx: Option<broadcast::Receiver<String>> = None;
        loop {
            tokio::select! {
                Some(Ok(msg)) = stream.next() => {
                    match msg {
                        Message::Text(txt) => {
                            if let Ok(v) = serde_json::from_str::<serde_json::Value>(&txt) {
                                let action = v.get("action").and_then(|a| a.as_str()).unwrap_or("");
                                let topic = v.get("topic").and_then(|t| t.as_str()).unwrap_or("default");
                                match action {
                                    "subscribe" => { rx = Some(hub.subscribe(topic)); }
                                    "broadcast" => {
                                        let payload = v.get("payload").cloned()
                                            .unwrap_or(serde_json::json!({}));
                                        hub.broadcast(topic, &payload.to_string());
                                    }
                                    _ => {}
                                }
                            }
                        }
                        Message::Ping(b) => { let _ = session.pong(&b).await; }
                        Message::Close(_) => break,
                        _ => {}
                    }
                }
                msg = async { match &mut rx { Some(r) => r.recv().await.ok(), None => { tokio::time::sleep(std::time::Duration::from_secs(60)).await; None } } } => {
                    if let Some(m) = msg { let _ = session.text(m).await; }
                }
            }
        }
    });
    Ok(resp)
}

// ── Main ──────────────────────────────────────────────────────────────
#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let mut cfg = Config::new();
    cfg.host     = Some(std::env::var("DB_HOST").unwrap_or("postgres".into()));
    cfg.port     = Some(5432);
    cfg.dbname   = Some("bench".into());
    cfg.user     = Some("bench".into());
    cfg.password = Some("bench".into());
    let pool = cfg.create_pool(Some(Runtime::Tokio1), tokio_postgres::NoTls).unwrap();

    let hub = web::Data::new(Arc::new(WsHub::new()));

    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(pool.clone()))
            .app_data(hub.clone())
            .route("/items", web::post().to(create_item))
            .route("/items/{id}", web::get().to(get_item))
            .route("/ws", web::get().to(ws_handler))
    })
    .workers(std::thread::available_parallelism().map(|n| n.get()).unwrap_or(2))
    .backlog(2048)
    .bind("0.0.0.0:8080")?
    .run()
    .await
}
