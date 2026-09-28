-- ============================================================================
-- MurtiTrack - Scheduled Jobs (pg_cron)
-- 14-Day Automated Image Cleanup & Security Pruning
-- ============================================================================

-- Function to prune expired photos and log execution
CREATE OR REPLACE FUNCTION purge_expired_media()
RETURNS TABLE(deleted_booking_photos INT, deleted_change_photos INT) AS $$
DECLARE
  v_bp_count INT := 0;
  v_cr_count INT := 0;
  v_start_time TIMESTAMPTZ := clock_timestamp();
BEGIN
  -- 1. Mark expired booking photos
  UPDATE booking_photos
  SET cleanup_status = 'expired'
  WHERE expires_at < NOW() AND cleanup_status = 'active';

  -- 2. Delete expired records
  WITH del_bp AS (
    DELETE FROM booking_photos
    WHERE cleanup_status = 'expired'
    RETURNING id
  )
  SELECT COUNT(*) INTO v_bp_count FROM del_bp;

  -- 3. Delete expired change request photos
  WITH del_cr AS (
    DELETE FROM change_request_photos
    WHERE expires_at < NOW()
    RETURNING id
  )
  SELECT COUNT(*) INTO v_cr_count FROM del_cr;

  -- 4. Record execution in cleanup_logs
  INSERT INTO cleanup_logs (job_type, files_deleted, duration_ms)
  VALUES (
    'image_cleanup',
    v_bp_count + v_cr_count,
    ROUND(EXTRACT(EPOCH FROM (clock_timestamp() - v_start_time)) * 1000)::INT
  );

  deleted_booking_photos := v_bp_count;
  deleted_change_photos := v_cr_count;
  RETURN NEXT;
END;
$$ LANGUAGE plpgsql;

-- Schedule daily midnight image cleanup job via pg_cron
-- SELECT cron.schedule('murti-image-cleanup', '0 2 * * *', 'SELECT purge_expired_media();');

-- Schedule weekly pruning of login attempts older than 30 days
-- SELECT cron.schedule('murti-login-prune', '0 3 * * 0', $$DELETE FROM login_attempts WHERE created_at < NOW() - INTERVAL '30 days';$$);
