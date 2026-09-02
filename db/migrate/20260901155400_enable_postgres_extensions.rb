class EnablePostgresExtensions < ActiveRecord::Migration[8.1]
  def up
    enable_extension "pgcrypto"
    enable_extension "cube"          # BẮT BUỘC trước earthdistance (plan §19.1)
    enable_extension "earthdistance"
    enable_extension "pg_trgm"
    enable_extension "unaccent"

    # unaccent() không IMMUTABLE nên không index trực tiếp được. Wrapper này là
    # điều kiện để có index trgm cho tìm kiếm tiếng Việt (plan §19.14).
    # Vì có function tự viết, app dùng schema_format = :sql (config/application.rb).
    # Bản trong plan §19.14 không chạy được trên Postgres 17, cần hai sửa đổi:
    #   1. cast ::regdictionary — nếu không: "function unaccent(unknown, text) does not exist".
    #   2. schema-qualify (public.unaccent) — CREATE INDEX inline function body với
    #      search_path bị siết, nếu không: "text search dictionary unaccent does not exist".
    execute <<~SQL
      CREATE OR REPLACE FUNCTION public.immutable_unaccent(text) RETURNS text AS
        $$ SELECT public.unaccent('public.unaccent'::regdictionary, $1) $$
      LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE;
    SQL
  end

  def down
    execute "DROP FUNCTION IF EXISTS public.immutable_unaccent(text)"
    disable_extension "earthdistance"
    disable_extension "cube"
    disable_extension "unaccent"
    disable_extension "pg_trgm"
    disable_extension "pgcrypto"
  end
end
