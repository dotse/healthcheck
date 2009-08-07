ALTER TABLE domains ADD COLUMN (last_import timestamp);
ALTER TABLE `tests` ADD COLUMN (run_id bigint(20) unsigned);