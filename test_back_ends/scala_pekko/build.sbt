val scala3Version = "3.4.2"

lazy val root = project
  .in(file("."))
  .settings(
    name := "benchmark-scala",
    version := "0.1.0",
    scalaVersion := scala3Version,
    libraryDependencies ++= Seq(
      "org.apache.pekko" %% "pekko-http" % "1.0.1",
      "org.apache.pekko" %% "pekko-stream" % "1.0.3",
      "org.apache.pekko" %% "pekko-actor-typed" % "1.0.3",
      "org.apache.pekko" %% "pekko-http-spray-json" % "1.0.1",
      "com.zaxxer" % "HikariCP" % "6.0.0",
      "org.postgresql" % "postgresql" % "42.7.4",
      "io.spray" %% "spray-json" % "1.3.6"
    ),
    assembly / mainClass := Some("benchmark.Main"),
    assembly / assemblyMergeStrategy := {
      case x if x.endsWith("module-info.class") => MergeStrategy.discard
      case x if x.contains("reference.conf") => MergeStrategy.concat
      case PathList("META-INF", xs @ _*) =>
        xs.map(_.toLowerCase) match {
          case "services" :: _ => MergeStrategy.concat
          case _ => MergeStrategy.discard
        }
      case _ => MergeStrategy.first
    }
  )
