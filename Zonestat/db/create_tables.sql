CREATE TABLE IF NOT EXISTS `zone` (
        `name` varchar(255) NOT NULL,
        `TTL` integer,
        `class` char(2) NOT NULL default 'IN',
        `type` varchar(10) NOT NULL,
        `data` varchar(32767) NOT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=ascii;

CREATE TABLE IF NOT EXISTS `webserver` (
    `id` serial primary key,
    `raw_type` varchar(512) NOT NULL,
    `type` varchar(255),
    `version` varchar(255),
    `https` boolean default FALSE,
    `issuer` varchar(512),
    `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    `domain_id` INT(10) unsigned,
    `testrun_id` bigint(20) unsigned not null,
    `ip` varchar(15) null,
    `url` varchar(255) not null,
    `raw_response` longtext,
    CONSTRAINT `webserver_domain` FOREIGN KEY (`domain_id`) REFERENCES `domains` (`id`) ON DELETE CASCADE,
    CONSTRAINT `webserver_testrun` FOREIGN KEY (`testrun_id`) REFERENCES `testruns` (`id`) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=UTF8;

CREATE TABLE IF NOT EXISTS `user` (
    `id` serial primary key,
    `displayname` varchar(255),
    `username` varchar(255) NOT NULL,
    `email` varchar(255) NOT NULL,
    `password` varchar(255) NOT NULL,
    INDEX user_username (username),
    INDEX user_password (password)
    ) ENGINE=InnoDB DEFAULT CHARSET=UTF8;

CREATE TABLE IF NOT EXISTS `domainset` (
    `id` serial primary key,
    `name` varchar(255) not null,
    INDEX domainset_name (name)
    ) ENGINE=InnoDB DEFAULT CHARSET=UTF8;
    
CREATE TABLE IF NOT EXISTS `domain_set_glue` (
    `id` serial primary key,
    `domain_id` int(10) unsigned not null,
    `set_id` bigint(20) unsigned not null,
    CONSTRAINT `glue_domainid` FOREIGN KEY (`domain_id`) REFERENCES `domains` (`id`) ON DELETE CASCADE,
    CONSTRAINT `glue_setid` FOREIGN KEY (`set_id`) REFERENCES `domainset` (`id`) ON DELETE CASCADE
    ) ENGINE=InnoDB;
    
CREATE TABLE IF NOT EXISTS `testruns` (
    `id` serial primary key,
    `set_id` bigint(20) unsigned not null,
    `name` varchar(255) unique not null,
    `start` timestamp DEFAULT CURRENT_TIMESTAMP,
    `finish` timestamp NULL,
    CONSTRAINT `testruns_setid` FOREIGN KEY (`set_id`) REFERENCES `domainset` (`id`) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=UTF8;