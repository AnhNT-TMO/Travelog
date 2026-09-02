class SyncUserPlaceVisitStats < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE user_places
      SET visits_count = visit_stats.visits_count,
          first_visited_at = visit_stats.first_visited_at,
          last_visited_at = visit_stats.last_visited_at,
          status = CASE WHEN visit_stats.visits_count > 0 THEN 1 ELSE 0 END,
          updated_at = CURRENT_TIMESTAMP
      FROM (
        SELECT user_places.id,
               COUNT(visits.id)::integer AS visits_count,
               MIN(visits.visited_at) AS first_visited_at,
               MAX(visits.visited_at) AS last_visited_at
        FROM user_places
        LEFT JOIN visits ON visits.user_place_id = user_places.id
        GROUP BY user_places.id
      ) AS visit_stats
      WHERE user_places.id = visit_stats.id
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
