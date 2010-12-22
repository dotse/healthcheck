/*! SET FOREIGN_KEY_CHECKS=0 */;

ALTER TABLE domains ADD COLUMN (last_import timestamp);
ALTER TABLE `tests` ADD COLUMN (run_id bigint(20) unsigned);
