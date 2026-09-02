class EnablePostgresExtensions < ActiveRecord::Migration[8.1]
  def up
    enable_extension "pgcrypto"
    enable_extension "cube"
    enable_extension "earthdistance"
    enable_extension "pg_trgm"
    enable_extension "unaccent"

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
