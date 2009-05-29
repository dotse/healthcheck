CREATE TABLE IF NOT EXISTS `zone` (
        `name` varchar(255) NOT NULL,
        `TTL` integer,
        `class` char(2) NOT NULL default 'IN',
        `type` varchar(10) NOT NULL,
        `data` varchar(32767) NOT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=ascii;
