ALTER TABLE domains ADD COLUMN (last_import timestamp);
ALTER TABLE `tests` ADD COLUMN (run_id bigint(20) unsigned);
CREATE UNIQUE INDEX `testruns_name_setid` ON `testruns` (`name`,`set_id`);
ALTER TABLE `domainset` ADD COLUMN (`dsgroup_id` bigint(20) unsigned NOT NULL);