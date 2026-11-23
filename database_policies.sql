-- FAMILY QUEST: exported RLS policy reference. NOT a runnable migration.
-- Export date: 2026-11-23

-- families / families_read / SELECT / roles {authenticated}
-- USING: (id IN ( SELECT my_family_ids() AS my_family_ids))
-- CHECK: null

-- history / history_read / SELECT / roles {authenticated}
-- USING: (family_id IN ( SELECT my_family_ids() AS my_family_ids))
-- CHECK: null

-- members / members_read / SELECT / roles {authenticated}
-- USING: (family_id IN ( SELECT my_family_ids() AS my_family_ids))
-- CHECK: null

-- monthly_archive / archive_read / SELECT / roles {authenticated}
-- USING: (family_id IN ( SELECT my_family_ids() AS my_family_ids))
-- CHECK: null

-- rewards / rewards_read / SELECT / roles {authenticated}
-- USING: (family_id IN ( SELECT my_family_ids() AS my_family_ids))
-- CHECK: null

-- tasks / tasks_read / SELECT / roles {authenticated}
-- USING: (family_id IN ( SELECT my_family_ids() AS my_family_ids))
-- CHECK: null

