/*! SET FOREIGN_KEY_CHECKS=0 */;

CREATE TABLE IF NOT EXISTS `zone` (
        `name` varchar(255) NOT NULL,
        `TTL` integer,
        `class` char(2) NOT NULL default 'IN',
        `type` varchar(10) NOT NULL,
        `data` varchar(32767) NOT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=ascii;

CREATE TABLE IF NOT EXISTS `domainset` (
    `id` serial primary key,
    `name` varchar(255) not null,
    `dsgroup_id` bigint(20) unsigned not null,
    `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    INDEX domainset_name (name)
    ) ENGINE=InnoDB DEFAULT CHARSET=UTF8;

CREATE TABLE IF NOT EXISTS `testruns` (
    `id` serial primary key,
    `set_id` bigint(20) unsigned not null,
    `name` varchar(255) not null,
    `start` timestamp DEFAULT CURRENT_TIMESTAMP,
    `finish` timestamp NULL,
    CONSTRAINT `testruns_setid` FOREIGN KEY (`set_id`) REFERENCES `domainset` (`id`) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=UTF8;    

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
    `response_code` int(10) unsigned,
    `content_type` varchar(255),
    `content_length` int(10) unsigned,
    `charset` varchar(255),
    `redirect_count` int(10) unsigned default 0,
    `redirect_urls` varchar(5120),
    `ending_tld` varchar(63),
    `robots_txt` boolean DEFAULT false,
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

CREATE TABLE IF NOT EXISTS `domain_set_glue` (
    `id` serial primary key,
    `domain_id` int(10) unsigned not null,
    `set_id` bigint(20) unsigned not null,
    CONSTRAINT `glue_domainid` FOREIGN KEY (`domain_id`) REFERENCES `domains` (`id`) ON DELETE CASCADE,
    CONSTRAINT `glue_setid` FOREIGN KEY (`set_id`) REFERENCES `domainset` (`id`) ON DELETE CASCADE
    ) ENGINE=InnoDB;
    

# Tables for dns2db import

CREATE TABLE IF NOT EXISTS `dns2db` (
    `id` serial primary key,
    `imported_at` date not null,
    `server` varchar(255) not null,
    CONSTRAINT UNIQUE (imported_at,server)
    ) ENGINE=InnoDB;
    
CREATE TABLE IF NOT EXISTS `d2d_ipv6stats` (
    `id` serial primary key,
    datum varchar(255),
    tid varchar(255),
    iptot integer default 0,
    ipv6total integer default 0,
    ipv6aaaa integer default 0,
    ipv6ns integer default 0,
    ipv6mx integer default 0,
    ipv6a integer default 0,
    ipv6soa integer default 0,
    ipv6ds integer default 0,
    ipv6a6 integer default 0,
    ipv4total integer default 0,
    ipv4aaaa integer default 0,
    ipv4ns integer default 0,
    ipv4mx integer default 0,
    ipv4a integer default 0,
    ipv4soa integer default 0,
    ipv4ds integer default 0,
    ipv4a6 integer default 0,
    dns2db_id bigint(20) unsigned not null,
    CONSTRAINT `ipv6stats_d2did` FOREIGN KEY (`dns2db_id`) REFERENCES `dns2db` (`id`) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=UTF8;
    
CREATE TABLE IF NOT EXISTS `d2d_topresolvers` (
    `id` serial primary key,
    src varchar(255), 
    qcount integer default 0,
    dnssec integer default 0,
    dns2db_id bigint(20) unsigned not null,
    CONSTRAINT `topresolvers_d2did` FOREIGN KEY (`dns2db_id`) REFERENCES `dns2db` (`id`) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=UTF8;
        
CREATE TABLE IF NOT EXISTS `d2d_v6as` (
    `id` serial primary key,
    foreign_id integer,
    date text,
    count integer default 0,
    asname text,
    country text,
    description text,
    dns2db_id bigint(20) unsigned not null,
    CONSTRAINT `v6as_d2did` FOREIGN KEY (`dns2db_id`) REFERENCES `dns2db` (`id`) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=UTF8;
    
CREATE TABLE IF NOT EXISTS `server` (
    `id` serial primary key,
    `kind` varchar(10),
    `country` varchar(128),
    `code` char(2),
    `ip` varchar(255),
    `ipv6` boolean not null default false,
    `asn` bigint,
    `city` varchar(255),
    `latitude` double,
    `longitude` double,
    `run_id` bigint(20) unsigned not null,
    `domain_id` int(10) unsigned not null,
    `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `server_runid` FOREIGN KEY (`run_id`) REFERENCES `testruns` (`id`) ON DELETE CASCADE,
    CONSTRAINT `server_domainid` FOREIGN KEY (`domain_id`) REFERENCES `domains` (`id`) ON DELETE CASCADE,
    UNIQUE (`kind`, `ip`, `run_id`, `domain_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=UTF8;
    
CREATE TABLE IF NOT EXISTS `asdata` (
    `id` serial primary key,
    `asn` varchar(10) unique not null,
    `asname` varchar(255),
    `descr` text
    ) ENGINE=InnoDB DEFAULT CHARSET=UTF8;
    
CREATE TABLE IF NOT EXISTS `mailserver` (
    `id` serial primary key,
    `name` varchar(255) not null,
    `starttls` boolean not null default false,
    `adsp` varchar(512),
    `ip` varchar(255) not null,
    `run_id` bigint(20) unsigned not null,
    `domain_id` int(10) unsigned not null,
    `banner` varchar(255),
    `spf_spf` varchar(255),
    `spf_txt` varchar(255),
    CONSTRAINT `mailserver_runid` FOREIGN KEY (`run_id`) REFERENCES `testruns` (`id`) ON DELETE CASCADE,
    CONSTRAINT `mailserver_domainid` FOREIGN KEY (`domain_id`) REFERENCES `domains` (`id`) ON DELETE CASCADE,
    INDEX (`name`),
    INDEX (`run_id`),
    INDEX (`domain_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=UTF8;
    
CREATE TABLE IF NOT EXISTS `pageanalysis` (
    `id` serial primary key,
    `webserver_id` bigint(20) unsigned not null,
    `load_time` double,
    `requests` int,
    `rx_bytes` int,
    `compressed_resources` int,
    `average_compression` double,
    `effective_compression` double,
    `external_resources` int,
    `error` varchar(255),
    CONSTRAINT `pageanalysis_webserverid` FOREIGN KEY (`webserver_id`) REFERENCES `webserver` (`id`) ON DELETE CASCADE,
    INDEX (`webserver_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=UTF8;
    
CREATE TABLE IF NOT EXISTS `pa_row` (
    `id` serial primary key,
    `pageanalysis_id` bigint(20) unsigned not null,
    `url` varchar(255),
    `ip` varchar(255),
    `resource_type` varchar(255),
    `found_in` varchar(255),
    `depth` int,
    `start_order` int,
    `offset_time` double,
    `time_in_queue` double,
    `dns_lookup_time` double,
    `connect_time` double,
    `redirect_time` double,
    `first_byte` double,
    `download_time` double,
    `load_time` double,
    `status_code` int,
    `compressed` boolean,
    `compression_ratio` double,
    `compressed_file_size` int,
    `file_size` int,
    `request_headers` varchar(2048),
    `response_headers` varchar(2048),
    `error` varchar(255),
    CONSTRAINT `parow_pageanalysisid` FOREIGN KEY (`pageanalysis_id`) REFERENCES `pageanalysis` (`id`) ON DELETE CASCADE,
    INDEX (`pageanalysis_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=UTF8;
    
CREATE TABLE IF NOT EXISTS `chi_Zonestat` (
    `key` varchar(600) NOT NULL default '',
    `value` longtext,
    PRIMARY KEY  (`key`)
    ) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE IF NOT EXISTS `dsgroup` (
    `id` serial primary key,
    `name` varchar(255) not null unique,
    INDEX (`name`)
    ) ENGINE=InnoDB DEFAULT CHARSET=UTF8;
    
CREATE TABLE IF NOT EXISTS `sslscan` (
    `id` serial primary key,
    `xml` text,
    `port` integer,
    `run_id` bigint(20) unsigned not null,
    `domain_id` int(10) unsigned not null,
    `name` varchar(255) not null,
    CONSTRAINT `sslscan_runid` FOREIGN KEY (`run_id`) REFERENCES `testruns` (`id`) ON DELETE CASCADE,
    CONSTRAINT `sslscan_domainid` FOREIGN KEY (`domain_id`) REFERENCES `domains` (`id`) ON DELETE CASCADE,
    INDEX (`run_id`),
    INDEX (`domain_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=UTF8;

CREATE TABLE `rawresponses` (
    `id` serial primary key,
    `webserver_id` bigint(20) unsigned NOT NULL,
    `raw_response` longtext,
    INDEX (`webserver_id`),
    CONSTRAINT `rawresponses_webserverid` FOREIGN KEY (`webserver_id`) REFERENCES `webserver` (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
