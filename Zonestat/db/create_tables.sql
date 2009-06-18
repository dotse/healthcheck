CREATE TABLE IF NOT EXISTS `zone` (
        `name` varchar(255) NOT NULL,
        `TTL` integer,
        `class` char(2) NOT NULL default 'IN',
        `type` varchar(10) NOT NULL,
        `data` varchar(32767) NOT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=ascii;

CREATE TABLE IF NOT EXISTS `webserver` (
    `id` serial primary key,
    `raw` varchar(512) NOT NULL,
    `type` varchar(255),
    `version` varchar(255),
    `https` boolean default FALSE,
    `issuer` varchar(512),
    `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    `domain_id` INT(10) unsigned,
    CONSTRAINT `webserver_domain` FOREIGN KEY (`domain_id`) REFERENCES `domains` (`id`) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=UTF8;
