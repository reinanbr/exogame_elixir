package benchmark

import org.apache.pekko.actor.typed.ActorSystem
import org.apache.pekko.actor.typed.scaladsl.Behaviors
import org.apache.pekko.http.scaladsl.Http
import org.apache.pekko.http.scaladsl.model.*
import org.apache.pekko.http.scaladsl.server.Directives.*
import org.apache.pekko.http.scaladsl.marshallers.sprayjson.SprayJsonSupport.*
import org.apache.pekko.http.scaladsl.model.ws.{Message, TextMessage}
import org.apache.pekko.stream.scaladsl.{BroadcastHub, Flow, Keep, MergeHub, Sink, Source}
import org.apache.pekko.stream.OverflowStrategy
import spray.json.*
import spray.json.DefaultJsonProtocol.*
import com.zaxxer.hikari.{HikariConfig, HikariDataSource}
import java.sql.{Connection, ResultSet}
import scala.concurrent.{ExecutionContext, Future}
import scala.util.{Try, Success, Failure}

case class Item(id: Int, name: String, value: String)
case class CreateItem(name: String, value: Option[String])

object ItemJsonProtocol extends DefaultJsonProtocol:
  given itemFormat: RootJsonFormat[Item] = jsonFormat3(Item.apply)
  given createItemFormat: RootJsonFormat[CreateItem] = jsonFormat2(CreateItem.apply)

object Main:
  import ItemJsonProtocol.given

  def main(args: Array[String]): Unit =
    given system: ActorSystem[Nothing] = ActorSystem(Behaviors.empty, "benchmark")
    given ec: ExecutionContext = system.executionContext

    val ds = initDb()

    // WebSocket broadcast hub
    val (wsSink, wsSource) = MergeHub.source[Message](256)
      .toMat(BroadcastHub.sink[Message](256))(Keep.both)
      .run()

    val wsFlow: Flow[Message, Message, Any] =
      Flow[Message]
        .via(Flow.fromSinkAndSource(wsSink, wsSource))

    val route =
      concat(
        path("items") {
          post {
            entity(as[CreateItem]) { body =>
              val name = body.name
              val value = body.value.getOrElse("")
              val item = Future {
                val conn = ds.getConnection()
                try
                  val ps = conn.prepareStatement(
                    "INSERT INTO items (name, value) VALUES (?, ?) RETURNING id, name, value"
                  )
                  ps.setString(1, name)
                  ps.setString(2, value)
                  val rs = ps.executeQuery()
                  if rs.next() then
                    Item(rs.getInt("id"), rs.getString("name"), rs.getString("value"))
                  else throw new Exception("insert failed")
                finally conn.close()
              }
              onComplete(item) {
                case Success(it) =>
                  complete(StatusCodes.Created, it)
                case Failure(ex) =>
                  complete(StatusCodes.InternalServerError,
                    JsObject("error" -> JsString(ex.getMessage)))
              }
            }
          }
        },
        path("items" / IntNumber) { id =>
          get {
            val item = Future {
              val conn = ds.getConnection()
              try
                val ps = conn.prepareStatement("SELECT id, name, value FROM items WHERE id = ?")
                ps.setInt(1, id)
                val rs = ps.executeQuery()
                if rs.next() then
                  Some(Item(rs.getInt("id"), rs.getString("name"), rs.getString("value")))
                else None
              finally conn.close()
            }
            onComplete(item) {
              case Success(Some(it)) => complete(it)
              case Success(None) =>
                complete(StatusCodes.NotFound, JsObject("error" -> JsString("not found")))
              case Failure(ex) =>
                complete(StatusCodes.InternalServerError,
                  JsObject("error" -> JsString(ex.getMessage)))
            }
          }
        },
        path("ws") {
          handleWebSocketMessages(wsFlow)
        }
      )

    Http().newServerAt("0.0.0.0", 8080).bind(route)
    println("Scala/Pekko HTTP server on :8080")

  private def initDb(): HikariDataSource =
    val host = Option(System.getenv("DB_HOST")).getOrElse("postgres")
    var ds: HikariDataSource = null
    for attempt <- 1 to 30 if ds == null do
      try
        val config = new HikariConfig()
        config.setJdbcUrl(s"jdbc:postgresql://$host:5432/bench")
        config.setUsername("bench")
        config.setPassword("bench")
        config.setMaximumPoolSize(16)
        config.setMinimumIdle(4)
        ds = new HikariDataSource(config)
        println("Connected to PostgreSQL")
      catch case e: Exception =>
        println(s"DB not ready ($attempt/30): ${e.getMessage}")
        Thread.sleep(1000)
    if ds == null then throw new Exception("Failed to connect to DB")
    ds
