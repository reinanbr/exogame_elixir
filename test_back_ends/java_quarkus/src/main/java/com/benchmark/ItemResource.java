package com.benchmark;

import io.smallrye.mutiny.Uni;
import io.vertx.mutiny.pgclient.PgPool;
import io.vertx.mutiny.sqlclient.Row;
import io.vertx.mutiny.sqlclient.RowSet;
import io.vertx.mutiny.sqlclient.Tuple;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import java.util.Map;

@Path("/items")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class ItemResource {

    @Inject
    PgPool client;

    @POST
    public Uni<Response> create(Map<String, String> body) {
        String name = body.get("name");
        String value = body.getOrDefault("value", "");
        if (name == null) {
            return Uni.createFrom().item(
                Response.status(400).entity(Map.of("error", "missing name")).build());
        }
        return client.preparedQuery(
                "INSERT INTO items (name, value) VALUES ($1, $2) RETURNING id, name, value")
            .execute(Tuple.of(name, value))
            .onItem().transform(rows -> {
                Row row = rows.iterator().next();
                return Response.status(201).entity(Map.of(
                    "id", row.getInteger("id"),
                    "name", row.getString("name"),
                    "value", row.getString("value")
                )).build();
            });
    }

    @GET
    @Path("/{id}")
    public Uni<Response> get(@PathParam("id") int id) {
        return client.preparedQuery("SELECT id, name, value FROM items WHERE id=$1")
            .execute(Tuple.of(id))
            .onItem().transform(rows -> {
                RowSet<Row> rs = rows;
                if (rs.size() == 0) {
                    return Response.status(404).entity(Map.of("error", "not found")).build();
                }
                Row row = rs.iterator().next();
                return Response.ok(Map.of(
                    "id", row.getInteger("id"),
                    "name", row.getString("name"),
                    "value", row.getString("value")
                )).build();
            });
    }
}
