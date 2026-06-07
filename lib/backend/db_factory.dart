import 'package:topal_iptv/backend/utils.dart';
import 'package:sqlite_async/sqlite_async.dart';

class DbFactory {
  static SqliteDatabase? _db;
  static String? _testPath;

  static Future<SqliteDatabase> _createDB() async {
    var db = SqliteDatabase(
      path: _testPath ?? "${await Utils.appDir}/db.sqlite",
    );
    var migrations = SqliteMigrations()
      ..add(
        SqliteMigration(1, (tx) async {
          await tx.execute('''
        CREATE TABLE "sources" (
          "id"          INTEGER PRIMARY KEY,
          "name"        varchar(100),
          "source_type" integer,
          "url"         varchar(500),
          "username"    varchar(100),
          "password"    varchar(100),
          "enabled"     integer DEFAULT 1
        );
        ''');
          await tx.execute('''
        CREATE TABLE "channels" (
          "id" INTEGER PRIMARY KEY,
          "name" varchar(100),
          "group_name" varchar(100),
          "image" varchar(500),
          "url" varchar(500),
          "media_type" integer,
          "source_id" integer,
          "favorite" integer,
          "series_id" integer,
          "group_id" integer,
          "stream_id" integer,
          FOREIGN KEY (source_id) REFERENCES sources(id)
          FOREIGN KEY (group_id) REFERENCES groups(id)
        );
        ''');
          await tx.execute('''
        CREATE TABLE "channel_http_headers" (
            "id" INTEGER PRIMARY KEY,
            "channel_id" integer,
            "referrer" varchar(500),
            "user_agent" varchar(500),
            "http_origin" varchar(500),
            "ignore_ssl" integer DEFAULT 0,
            FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE CASCADE
        );
        ''');
          await tx.execute('''
        CREATE TABLE "movie_positions" (
          "id" INTEGER PRIMARY KEY,
          "channel_id" integer,
          "position" int,
          FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE CASCADE
        )
        ''');
          await tx.execute('''
        CREATE TABLE "settings" (
          "key" VARCHAR(50) PRIMARY KEY,
          "value" VARCHAR(100)
        );
        ''');
          await tx.execute('''
          CREATE TABLE "groups" (
            "id" INTEGER PRIMARY KEY,
            "name" varchar(100),
            "image" varchar(500),
            "source_id" integer,
            FOREIGN KEY (source_id) REFERENCES sources(id)
          );
        ''');
          await tx.execute(
            '''CREATE INDEX index_channel_name ON channels(name);''',
          );
          await tx.execute(
            '''CREATE UNIQUE INDEX channels_unique ON channels(name, source_id);''',
          );
          await tx.execute(
            '''CREATE UNIQUE INDEX index_source_name ON sources(name);''',
          );
          await tx.execute(
            '''CREATE INDEX index_source_enabled ON sources(enabled);''',
          );
          await tx.execute(
            '''CREATE UNIQUE INDEX index_group_unique ON groups(name, source_id);''',
          );
          await tx.execute(
            '''CREATE INDEX index_group_name ON groups(name);''',
          );
          await tx.execute(
            '''CREATE INDEX index_channel_source_id ON channels(source_id);''',
          );
          await tx.execute(
            '''CREATE INDEX index_channel_favorite ON channels(favorite);''',
          );
          await tx.execute(
            '''CREATE INDEX index_channel_series_id ON channels(series_id);''',
          );
          await tx.execute(
            '''CREATE INDEX index_channel_group_id ON channels(group_id);''',
          );
          await tx.execute(
            '''CREATE INDEX index_channel_media_type ON channels(media_type);''',
          );
          await tx.execute(
            '''CREATE INDEX index_channels_stream_id ON channels(stream_id);''',
          );
          await tx.execute(
            '''CREATE INDEX index_channels_group_name ON channels(group_name);''',
          );
          await tx.execute(
            '''CREATE INDEX index_group_source_id ON groups(source_id);''',
          );
          await tx.execute('''
          CREATE UNIQUE INDEX index_channel_http_headers_channel_id ON channel_http_headers(channel_id);
        ''');
          await tx.execute('''
          CREATE UNIQUE INDEX index_movie_positions_channel_id ON movie_positions(channel_id);
        ''');
        }),
      )
      ..add(
        SqliteMigration(2, (tx) async {
          await tx.execute('''
          ALTER TABLE channels
          ADD COLUMN last_watched integer;
        ''');
          await tx.execute('''
          CREATE INDEX index_channel_last_watched ON channels(last_watched);
        ''');
        }),
      )
      ..add(
        SqliteMigration(3, (tx) async {
          await tx.execute('''
          ALTER TABLE groups
          ADD COLUMN media_type integer;
        ''');
          await tx.execute('''
          CREATE INDEX index_groups_media_type ON groups(media_type);
        ''');
        }),
      )
      ..add(
        SqliteMigration(4, (tx) async {
          await tx.execute('''
          ALTER TABLE channels
          ADD COLUMN variant_key varchar(500);
        ''');
          await tx.execute('''
          UPDATE channels
          SET variant_key = CASE
            WHEN media_type = 0 AND stream_id IS NOT NULL AND stream_id >= 0
              THEN 'live:' || stream_id
            WHEN media_type = 1 AND series_id IS NOT NULL
              THEN 'episode:' || series_id || ':' || ifnull(url, name)
            WHEN media_type = 1 AND stream_id IS NOT NULL AND stream_id >= 0
              THEN 'movie:' || stream_id
            WHEN media_type = 2
              THEN 'series:' || ifnull(url, name)
            ELSE 'url:' || media_type || ':' || ifnull(url, name)
          END
          WHERE variant_key IS NULL OR variant_key = '';
        ''');
          await tx.execute('''DROP INDEX IF EXISTS channels_unique;''');
          await tx.execute('''
          CREATE UNIQUE INDEX channels_unique
          ON channels(source_id, variant_key);
        ''');
          await tx.execute('''
          CREATE INDEX index_channels_variant_key ON channels(variant_key);
        ''');
        }),
      )
      ..add(
        SqliteMigration(5, (tx) async {
          await tx.execute('''
          CREATE TABLE "epg_programs" (
            "id" INTEGER PRIMARY KEY,
            "channel_id" integer,
            "source_id" integer,
            "stream_id" integer,
            "title" varchar(500),
            "description" text,
            "start_timestamp" integer,
            "stop_timestamp" integer,
            "fetched_at" integer,
            FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE CASCADE,
            FOREIGN KEY (source_id) REFERENCES sources(id) ON DELETE CASCADE
          );
        ''');
          await tx.execute(
            '''CREATE INDEX index_epg_programs_channel_id ON epg_programs(channel_id);''',
          );
          await tx.execute(
            '''CREATE INDEX index_epg_programs_source_id ON epg_programs(source_id);''',
          );
          await tx.execute(
            '''CREATE INDEX index_epg_programs_stream_id ON epg_programs(stream_id);''',
          );
          await tx.execute(
            '''CREATE INDEX index_epg_programs_time ON epg_programs(channel_id, start_timestamp, stop_timestamp);''',
          );
          await tx.execute(
            '''CREATE INDEX index_epg_programs_fetched_at ON epg_programs(fetched_at);''',
          );
        }),
      )
      ..add(
        SqliteMigration(6, (tx) async {
          await tx.execute('''
          CREATE TABLE "media_metadata" (
            "id" INTEGER PRIMARY KEY,
            "channel_id" integer,
            "source_id" integer,
            "synopsis" text,
            "year" varchar(20),
            "rating" varchar(20),
            "duration_seconds" integer,
            "genres" text,
            "cast" text,
            "backdrop" varchar(500),
            "poster" varchar(500),
            "fetched_at" integer,
            FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE CASCADE,
            FOREIGN KEY (source_id) REFERENCES sources(id) ON DELETE CASCADE
          );
        ''');
          await tx.execute(
            '''CREATE UNIQUE INDEX index_media_metadata_channel_id ON media_metadata(channel_id);''',
          );
          await tx.execute(
            '''CREATE INDEX index_media_metadata_source_id ON media_metadata(source_id);''',
          );
          await tx.execute(
            '''CREATE INDEX index_media_metadata_fetched_at ON media_metadata(fetched_at);''',
          );
        }),
      );
    await migrations.migrate(db);
    return db;
  }

  static Future<SqliteDatabase> get db async {
    _db ??= await _createDB();
    return _db!;
  }

  static Future<void> usePathForTesting(String path) async {
    await resetForTesting();
    _testPath = path;
    _db = await _createDB();
  }

  static Future<void> resetForTesting() async {
    await _db?.close();
    _db = null;
    _testPath = null;
  }
}
